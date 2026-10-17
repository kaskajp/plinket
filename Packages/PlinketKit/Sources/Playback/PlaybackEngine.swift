import Foundation

/// One queue entry as the engine sees it: the entry's identity and where to stream it from.
public struct PlaybackItem: Sendable, Hashable, Identifiable {
    public let id: UUID
    public let url: URL
    /// The server-reported MIME type, used when the URL alone doesn't reveal the format.
    public let contentType: String?

    public init(id: UUID, url: URL, contentType: String? = nil) {
        self.id = id
        self.url = url
        self.contentType = contentType
    }
}

/// Something the engine observed while playing.
public enum PlaybackEngineEvent: Sendable, Equatable {
    /// Periodic progress of the current item; `duration` is `nil` until the media reports it.
    case progressed(position: TimeInterval, duration: TimeInterval?)
    /// The current item finished and the preloaded item took over without a reload.
    case advanced(to: PlaybackItem.ID)
    /// The current item finished with nothing preloaded after it.
    case reachedEnd
    case failed(itemID: PlaybackItem.ID, message: String)
}

/// Plays a current item while keeping the following one preloaded.
@MainActor
public protocol PlaybackEngine: AnyObject {
    var onEvent: (@MainActor (PlaybackEngineEvent) -> Void)? { get set }

    /// Replaces everything loaded. Playback state (playing or paused) is left to ``play()`` and ``pause()``.
    func load(_ current: PlaybackItem, startingAt position: TimeInterval, next: PlaybackItem?)
    /// Swaps the item that follows the current one, leaving the current item untouched.
    func preload(next: PlaybackItem?)
    func play()
    func pause()
    func seek(to position: TimeInterval)
    /// Stops and unloads everything.
    func stop()
}
