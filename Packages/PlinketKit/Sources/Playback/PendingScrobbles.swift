import Foundation

/// A finished play waiting to be submitted to the server.
public struct PendingScrobble: Hashable, Sendable, Codable {
    public let songID: String
    public let playedAt: Date

    public init(songID: String, playedAt: Date) {
        self.songID = songID
        self.playedAt = playedAt
    }
}

/// Plays whose submission failed, kept in the order they were added for a later retry.
public struct PendingScrobbles: Sendable, Equatable, Codable {
    public private(set) var scrobbles: [PendingScrobble]

    public init(_ scrobbles: [PendingScrobble] = []) {
        self.scrobbles = []
        enqueue(contentsOf: scrobbles)
    }

    public var isEmpty: Bool { scrobbles.isEmpty }

    /// Adds `scrobble` unless the same song played at the same moment is already pending.
    public mutating func enqueue(_ scrobble: PendingScrobble) {
        guard !scrobbles.contains(scrobble) else { return }
        scrobbles.append(scrobble)
    }

    public mutating func enqueue(contentsOf newScrobbles: some Sequence<PendingScrobble>) {
        for scrobble in newScrobbles {
            enqueue(scrobble)
        }
    }

    /// Removes and returns every pending scrobble in the order they were added.
    public mutating func dequeueAll() -> [PendingScrobble] {
        defer { scrobbles = [] }
        return scrobbles
    }
}
