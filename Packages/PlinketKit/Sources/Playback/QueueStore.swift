import Foundation
import Subsonic

/// The queue and where playback was within the current song.
public struct SavedPlayback: Codable, Sendable, Equatable {
    public var queue: PlayQueue<Song>
    public var position: TimeInterval

    public init(queue: PlayQueue<Song>, position: TimeInterval) {
        self.queue = queue
        self.position = position
    }
}

/// Persists the play queue so a relaunch can pick up where playback left off.
@MainActor
public final class QueueStore {
    static let fileName = "queue.json"

    private let file: JSONFile<SavedPlayback>
    private let saveDelay: Duration
    private var unsavedPlayback: SavedPlayback?
    private var saveTask: Task<Void, Never>?

    public init(directory: URL = PlaybackStorage.defaultDirectory, saveDelay: Duration = .seconds(2)) {
        file = JSONFile(url: directory.appending(path: Self.fileName))
        self.saveDelay = saveDelay
    }

    public func load() async -> SavedPlayback? {
        await file.load()
    }

    /// Writes `playback` within `saveDelay`. Calls in the meantime only replace what gets written, so
    /// position updates during playback cost one write per interval rather than one per update.
    public func save(_ playback: SavedPlayback) {
        unsavedPlayback = playback
        guard saveTask == nil else { return }
        let saveDelay = saveDelay
        saveTask = Task { [weak self] in
            do {
                try await Task.sleep(for: saveDelay)
            } catch {
                return
            }
            await self?.writeUnsavedPlayback()
        }
    }

    /// Writes any change still waiting for its delayed save.
    public func flush() async {
        await writeUnsavedPlayback()
    }

    /// Deletes the saved queue, including any change still waiting to be written.
    public func remove() async {
        cancelScheduledSave()
        unsavedPlayback = nil
        await file.remove()
    }

    private func writeUnsavedPlayback() async {
        cancelScheduledSave()
        guard let unsavedPlayback else { return }
        self.unsavedPlayback = nil
        await file.save(unsavedPlayback)
    }

    private func cancelScheduledSave() {
        saveTask?.cancel()
        saveTask = nil
    }
}
