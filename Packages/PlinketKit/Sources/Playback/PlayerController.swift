import Foundation
import Observation
import Subsonic

/// A song that could not be played.
public struct PlaybackError: Error, Sendable, Equatable {
    public let songTitle: String
    public let message: String
}

/// The player: owns the queue, drives the engine and keeps both in step.
@MainActor
@Observable
public final class PlayerController {
    /// Past this position, "previous" restarts the current song instead of going back.
    public static let restartThreshold: TimeInterval = 3

    public private(set) var queue = PlayQueue<Song>()
    /// Whether playback is wanted; the engine may still be buffering.
    public private(set) var isPlaying = false
    public private(set) var position: TimeInterval = 0
    /// The most recent song that could not be played; cleared when another song starts.
    public private(set) var error: PlaybackError?
    private var mediaDuration: TimeInterval?

    @ObservationIgnored private let engine: any PlaybackEngine
    @ObservationIgnored private let streamURL: @MainActor (Song) -> URL
    @ObservationIgnored private let scrobbler: Scrobbler?
    @ObservationIgnored private let queueStore: QueueStore?
    @ObservationIgnored private var loadedEntryID: UUID?
    @ObservationIgnored private var preloadedEntryID: UUID?
    @ObservationIgnored private var needsStartReport = false
    @ObservationIgnored private var hasLoadFailure = false
    @ObservationIgnored private var consecutiveFailures = 0

    public init(
        engine: any PlaybackEngine,
        streamURL: @escaping @MainActor (Song) -> URL,
        scrobbler: Scrobbler? = nil,
        queueStore: QueueStore? = nil
    ) {
        self.engine = engine
        self.streamURL = streamURL
        self.scrobbler = scrobbler
        self.queueStore = queueStore
        engine.onEvent = { [weak self] event in self?.handle(event) }
    }

    public convenience init(client: SubsonicClient, scrobbler: Scrobbler?, queueStore: QueueStore?) {
        self.init(
            engine: QueuePlayerEngine(),
            streamURL: { client.streamURL(songID: $0.id) },
            scrobbler: scrobbler,
            queueStore: queueStore
        )
    }

    public var currentSong: Song? { queue.current }
    public var currentIndex: Int? { queue.currentIndex }
    public var entries: [PlayQueue<Song>.Entry] { queue.entries }
    public var repeatMode: RepeatMode { queue.repeatMode }
    public var isShuffled: Bool { queue.isShuffled }

    /// The media's own duration once known, otherwise the server's metadata.
    public var duration: TimeInterval? {
        mediaDuration ?? queue.current?.duration.map(TimeInterval.init)
    }

    // MARK: - Starting playback

    public func play(songs: [Song], startingAt startIndex: Int = 0) {
        guard !songs.isEmpty else { return }
        queue.replace(with: songs, startingAt: startIndex)
        startCurrentEntry(at: 0, playing: true)
    }

    /// Plays `songs` in random order, starting from a random song.
    public func shuffle(songs: [Song]) {
        guard let startIndex = songs.indices.randomElement() else { return }
        queue.replace(with: songs, startingAt: startIndex)
        queue.setShuffle(true)
        startCurrentEntry(at: 0, playing: true)
    }

    /// Loads the queue saved by the previous launch, paused where it was left. Does nothing once something is queued.
    public func restoreSavedQueue() async {
        guard let saved = await queueStore?.load(), queue.isEmpty else { return }
        queue = saved.queue
        startCurrentEntry(at: saved.position, playing: false)
    }

    /// Writes the queue now instead of after the usual delay, e.g. when the app moves to the background.
    public func saveQueue() async {
        await queueStore?.flush()
    }

    /// Stops playback for good, e.g. on sign-out.
    public func shutDown() {
        engine.stop()
        isPlaying = false
        loadedEntryID = nil
        preloadedEntryID = nil
    }

    // MARK: - Transport

    public func play() {
        guard queue.currentEntry != nil else { return }
        if hasLoadFailure {
            startCurrentEntry(at: position, playing: true)
            return
        }
        isPlaying = true
        engine.play()
        reportStartIfNeeded()
    }

    public func pause() {
        isPlaying = false
        engine.pause()
        saveState()
    }

    public func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    public func next() {
        guard queue.skipForward() != nil else { return }
        startCurrentEntry(at: 0, playing: isPlaying)
    }

    /// Restarts the current song once past ``restartThreshold``, otherwise goes to the previous song.
    public func previous() {
        guard position <= Self.restartThreshold, queue.skipBackward() != nil else {
            seek(to: 0)
            return
        }
        startCurrentEntry(at: 0, playing: isPlaying)
    }

    public func seek(to newPosition: TimeInterval) {
        guard queue.currentEntry != nil else { return }
        position = min(max(newPosition, 0), duration ?? .greatestFiniteMagnitude)
        engine.seek(to: position)
        saveState()
    }

    public func setRepeat(_ mode: RepeatMode) {
        queue.repeatMode = mode
        queueDidChange()
    }

    public func setShuffle(_ isEnabled: Bool) {
        queue.setShuffle(isEnabled)
        queueDidChange()
    }

    public func toggleShuffle() {
        setShuffle(!queue.isShuffled)
    }

    // MARK: - Editing the queue

    public func playNext(_ songs: [Song]) {
        insert { $0.playNext(songs) }
    }

    public func addToQueue(_ songs: [Song]) {
        insert { $0.append(songs) }
    }

    /// Reorders entries with `List.onMove` semantics; the current song keeps playing.
    public func move(fromOffsets offsets: IndexSet, toOffset destination: Int) {
        queue.move(fromOffsets: offsets, toOffset: destination)
        queueDidChange()
    }

    /// Removes entries; removing the current one moves on to the song that followed it.
    public func remove(atOffsets offsets: IndexSet) {
        let previousEntryID = queue.currentEntry?.id
        queue.remove(atOffsets: offsets)
        guard queue.currentEntry?.id == previousEntryID else {
            startCurrentEntry(at: 0, playing: isPlaying)
            return
        }
        queueDidChange()
    }

    public func jump(to index: Int) {
        guard queue.jump(to: index) != nil else { return }
        startCurrentEntry(at: 0, playing: true)
    }

    // MARK: - Private

    private func insert(_ change: (inout PlayQueue<Song>) -> Void) {
        let wasEmpty = queue.isEmpty
        change(&queue)
        guard wasEmpty else {
            queueDidChange()
            return
        }
        startCurrentEntry(at: 0, playing: true)
    }

    private func startCurrentEntry(at startPosition: TimeInterval, playing shouldPlay: Bool) {
        error = nil
        consecutiveFailures = 0
        hasLoadFailure = false
        mediaDuration = nil
        position = startPosition
        guard let entry = queue.currentEntry else {
            shutDown()
            saveState()
            return
        }
        let nextEntry = queue.peekNextEntry()
        engine.load(playbackItem(for: entry), startingAt: startPosition, next: nextEntry.map(playbackItem(for:)))
        loadedEntryID = entry.id
        preloadedEntryID = nextEntry?.id
        needsStartReport = true
        if shouldPlay {
            play()
        } else {
            isPlaying = false
            engine.pause()
        }
        saveState()
    }

    private func queueDidChange() {
        preloadNextEntry()
        saveState()
    }

    private func preloadNextEntry() {
        let nextEntry = queue.peekNextEntry()
        guard nextEntry?.id != preloadedEntryID else { return }
        engine.preload(next: nextEntry.map(playbackItem(for:)))
        preloadedEntryID = nextEntry?.id
    }

    private func playbackItem(for entry: PlayQueue<Song>.Entry) -> PlaybackItem {
        PlaybackItem(id: entry.id, url: streamURL(entry.item), contentType: entry.item.contentType)
    }

    private func reportStartIfNeeded() {
        guard needsStartReport, isPlaying, let song = queue.current else { return }
        needsStartReport = false
        scrobbler?.trackStarted(songID: song.id, durationSeconds: song.duration.map(TimeInterval.init))
    }

    private func saveState() {
        queueStore?.save(SavedPlayback(queue: queue, position: position))
    }

    // MARK: - Engine events

    private func handle(_ event: PlaybackEngineEvent) {
        switch event {
        case .progressed(let newPosition, let newDuration):
            handleProgress(position: newPosition, duration: newDuration)
        case .advanced(let entryID):
            handleAdvance(to: entryID)
        case .reachedEnd:
            handleEndOfItem()
        case .failed(let entryID, let message):
            handleFailure(of: entryID, message: message)
        }
    }

    private func handleProgress(position newPosition: TimeInterval, duration newDuration: TimeInterval?) {
        position = newPosition
        mediaDuration = newDuration
        scrobbler?.positionChanged(to: newPosition)
        saveState()
    }

    /// The engine already moved on to the preloaded entry, so only the queue needs to catch up.
    private func handleAdvance(to entryID: UUID) {
        queue.advance()
        guard queue.currentEntry?.id == entryID else {
            startCurrentEntry(at: 0, playing: isPlaying)
            return
        }
        loadedEntryID = entryID
        preloadedEntryID = nil
        error = nil
        consecutiveFailures = 0
        mediaDuration = nil
        position = 0
        needsStartReport = true
        reportStartIfNeeded()
        queueDidChange()
    }

    /// Nothing was preloaded, which normally means the queue ended; that stops on the last song, rewound.
    private func handleEndOfItem() {
        let hasNextEntry = queue.advance() != nil
        startCurrentEntry(at: 0, playing: hasNextEntry)
    }

    /// Skips past unplayable songs while playing, giving up after every entry has failed in a row.
    private func handleFailure(of entryID: UUID, message: String) {
        guard entryID == loadedEntryID, let song = queue.current else { return }
        let failure = PlaybackError(songTitle: song.title, message: message)
        let failureCount = consecutiveFailures + 1
        let canSkip = isPlaying && failureCount < queue.entries.count && queue.skipForward() != nil
        if canSkip {
            startCurrentEntry(at: 0, playing: true)
        } else {
            isPlaying = false
            engine.pause()
            hasLoadFailure = true
        }
        error = failure
        consecutiveFailures = failureCount
    }
}
