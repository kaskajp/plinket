import Foundation

/// Accumulates time actually listened to from successive playback positions, so seeking ahead doesn't count.
public struct ListeningTracker: Sendable, Equatable {
    public private(set) var listenedSeconds: TimeInterval = 0
    /// Position changes larger than this between updates are treated as seeks, not listening.
    public let maximumContinuousStep: TimeInterval
    private var lastPosition: TimeInterval?

    public init(maximumContinuousStep: TimeInterval = 2) {
        self.maximumContinuousStep = maximumContinuousStep
    }

    /// Records the current playback position. The first call only establishes a starting point.
    public mutating func update(position: TimeInterval) {
        defer { lastPosition = position }
        guard let lastPosition else { return }
        let step = position - lastPosition
        guard step > 0, step <= maximumContinuousStep else { return }
        listenedSeconds += step
    }
}
