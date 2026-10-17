import Foundation

/// Decides when a play counts as a scrobble, following the Last.fm submission rules.
public struct ScrobblePolicy: Sendable, Equatable {
    /// Tracks must be strictly longer than this to be scrobbled at all.
    public var minimumTrackDuration: TimeInterval
    public var requiredPlayedFraction: Double
    /// Listening this long always counts, regardless of track length or when the length is unknown.
    public var sufficientPlayTime: TimeInterval

    public init(
        minimumTrackDuration: TimeInterval = 30,
        requiredPlayedFraction: Double = 0.5,
        sufficientPlayTime: TimeInterval = 240
    ) {
        self.minimumTrackDuration = minimumTrackDuration
        self.requiredPlayedFraction = requiredPlayedFraction
        self.sufficientPlayTime = sufficientPlayTime
    }

    /// Whether `playedSeconds` of listening to a track lasting `durationSeconds` should be submitted.
    ///
    /// A `nil` or non-positive duration is treated as unknown, leaving only the ``sufficientPlayTime`` rule.
    public func shouldSubmit(playedSeconds: TimeInterval, durationSeconds: TimeInterval?) -> Bool {
        guard let durationSeconds, durationSeconds > 0 else {
            return playedSeconds >= sufficientPlayTime
        }
        guard durationSeconds > minimumTrackDuration else { return false }
        let requiredPlayTime = min(durationSeconds * requiredPlayedFraction, sufficientPlayTime)
        return playedSeconds >= requiredPlayTime
    }
}
