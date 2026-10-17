/// How a ``PlayQueue`` behaves when playback reaches the end of the current item or the queue.
public enum RepeatMode: String, Codable, Sendable, CaseIterable {
    case off
    case all
    case one
}
