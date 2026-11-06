import Foundation

/// The requested encoding of a new offline download.
public enum DownloadFormat: String, Codable, CaseIterable, Sendable, Identifiable {
    case original, opus, mp3

    public var id: Self { self }

    public var title: String {
        switch self {
        case .original: "Original"
        case .opus: "Opus"
        case .mp3: "MP3"
        }
    }
}
