import AVFoundation
import OSLog

/// Plays through `AVQueuePlayer`, keeping the next item enqueued so tracks follow each other with minimal gap.
@MainActor
public final class QueuePlayerEngine: PlaybackEngine {
    private static let progressInterval = CMTime(seconds: 0.5, preferredTimescale: 600)
    private static let seekTimescale: CMTimeScale = 600

    public var onEvent: (@MainActor (PlaybackEngineEvent) -> Void)?

    private let player = AVQueuePlayer()
    private var current: LoadedItem?
    private var next: LoadedItem?
    /// A seek requested before the current item could seek, applied once it is ready.
    private var pendingSeekPosition: TimeInterval?
    private var timeObserver: Any?
    private var notificationObservers: [any NSObjectProtocol] = []

    public init() {
        player.actionAtItemEnd = .advance
        observeProgress()
        observeItemNotifications()
    }

    isolated deinit {
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
        }
        for observer in notificationObservers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    public func load(_ current: PlaybackItem, startingAt position: TimeInterval, next: PlaybackItem?) {
        player.removeAllItems()
        let loadedCurrent = makeLoadedItem(current)
        self.current = loadedCurrent
        self.next = nil
        pendingSeekPosition = position > 0 ? position : nil
        player.insert(loadedCurrent.playerItem, after: nil)
        preload(next: next)
    }

    public func preload(next item: PlaybackItem?) {
        if let next {
            player.remove(next.playerItem)
            self.next = nil
        }
        guard let current, let item else { return }
        let loadedNext = makeLoadedItem(item)
        next = loadedNext
        player.insert(loadedNext.playerItem, after: current.playerItem)
    }

    public func play() {
        player.play()
    }

    public func pause() {
        player.pause()
    }

    public func seek(to position: TimeInterval) {
        guard let current, current.playerItem.status == .readyToPlay else {
            pendingSeekPosition = position
            return
        }
        pendingSeekPosition = nil
        player.seek(
            to: CMTime(seconds: position, preferredTimescale: Self.seekTimescale),
            toleranceBefore: .zero,
            toleranceAfter: .zero
        )
    }

    public func stop() {
        player.pause()
        player.removeAllItems()
        current = nil
        next = nil
        pendingSeekPosition = nil
    }

    // MARK: - Observation

    private func makeLoadedItem(_ item: PlaybackItem) -> LoadedItem {
        // Without precise timing, seeks in FLAC (and VBR MP3) land far from the target while reporting it.
        var assetOptions: [String: Any] = [AVURLAssetPreferPreciseDurationAndTimingKey: true]
        if let contentType = item.contentType {
            assetOptions[AVURLAssetOverrideMIMETypeKey] = contentType
        }
        let playerItem = AVPlayerItem(asset: AVURLAsset(url: item.url, options: assetOptions))
        // KVO may fire on any thread, so hop to the main actor and re-read state there.
        let statusObservation = playerItem.observe(\.status) { @Sendable [weak self] _, _ in
            Task { @MainActor in self?.handleStatusChange() }
        }
        return LoadedItem(item: item, playerItem: playerItem, statusObservation: statusObservation)
    }

    private func observeProgress() {
        timeObserver = player.addPeriodicTimeObserver(forInterval: Self.progressInterval, queue: .main) { [weak self] time in
            MainActor.assumeIsolated { self?.reportProgress(at: time) }
        }
    }

    private func observeItemNotifications() {
        let center = NotificationCenter.default
        notificationObservers = [
            center.addObserver(forName: AVPlayerItem.didPlayToEndTimeNotification, object: nil, queue: .main) { [weak self] notification in
                guard let endedItem = notification.object as? AVPlayerItem else { return }
                let endedItemID = ObjectIdentifier(endedItem)
                MainActor.assumeIsolated { self?.handleItemEnded(endedItemID) }
            },
            center.addObserver(forName: AVPlayerItem.failedToPlayToEndTimeNotification, object: nil, queue: .main) { [weak self] notification in
                guard let failedItem = notification.object as? AVPlayerItem else { return }
                let failedItemID = ObjectIdentifier(failedItem)
                let message = (notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? any Error)?.localizedDescription
                MainActor.assumeIsolated { self?.handlePlaybackFailure(of: failedItemID, message: message) }
            },
        ]
    }

    private func reportProgress(at time: CMTime) {
        guard let current, player.currentItem === current.playerItem, time.isNumeric else { return }
        let itemDuration = current.playerItem.duration
        let duration = itemDuration.isNumeric ? itemDuration.seconds : nil
        onEvent?(.progressed(position: time.seconds, duration: duration))
    }

    private func handleStatusChange() {
        guard let current else { return }
        switch current.playerItem.status {
        case .readyToPlay:
            applyPendingSeek()
        case .failed:
            reportFailure(of: current, message: current.playerItem.error?.localizedDescription)
        default:
            return
        }
    }

    private func applyPendingSeek() {
        guard let pendingSeekPosition else { return }
        seek(to: pendingSeekPosition)
    }

    private func handleItemEnded(_ endedItemID: ObjectIdentifier) {
        guard let current, ObjectIdentifier(current.playerItem) == endedItemID else { return }
        guard let next else {
            self.current = nil
            onEvent?(.reachedEnd)
            return
        }
        self.current = next
        self.next = nil
        onEvent?(.advanced(to: next.item.id))
        if next.playerItem.status == .failed {
            reportFailure(of: next, message: next.playerItem.error?.localizedDescription)
        }
    }

    private func handlePlaybackFailure(of failedItemID: ObjectIdentifier, message: String?) {
        guard let current, ObjectIdentifier(current.playerItem) == failedItemID else { return }
        reportFailure(of: current, message: message)
    }

    private func reportFailure(of loadedItem: LoadedItem, message: String?) {
        guard !loadedItem.hasReportedFailure else { return }
        loadedItem.hasReportedFailure = true
        let message = message ?? String(localized: "The track could not be played.")
        Logger.playback.error("Playback failed: \(message)")
        onEvent?(.failed(itemID: loadedItem.item.id, message: message))
    }
}

@MainActor
private final class LoadedItem {
    let item: PlaybackItem
    let playerItem: AVPlayerItem
    let statusObservation: NSKeyValueObservation
    var hasReportedFailure = false

    init(item: PlaybackItem, playerItem: AVPlayerItem, statusObservation: NSKeyValueObservation) {
        self.item = item
        self.playerItem = playerItem
        self.statusObservation = statusObservation
    }
}

extension Logger {
    static let playback = Logger(subsystem: "nu.4z.plinket", category: "Playback")
}
