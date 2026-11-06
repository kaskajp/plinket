import Foundation
import Subsonic

public struct DownloadSettings: Codable, Sendable, Equatable {
    public var isEnabled: Bool
    public var format: DownloadFormat
    public var allowsCellular: Bool
    public var maximumBytes: Int64

    public init(
        isEnabled: Bool = true,
        format: DownloadFormat = .original,
        allowsCellular: Bool = false,
        maximumBytes: Int64 = 5_000_000_000
    ) {
        self.isEnabled = isEnabled
        self.format = format
        self.allowsCellular = allowsCellular
        self.maximumBytes = maximumBytes
    }
}

public enum DownloadError: LocalizedError {
    case disabled
    case insufficientSpace
    case limitBelowUsage
    case invalidAudio(DownloadFormat)
    case http(Int)

    public var errorDescription: String? {
        switch self {
        case .disabled: "Enable downloads in Settings before downloading music."
        case .insufficientSpace: "Not enough space for this download. Free device storage or increase Max Storage in Settings."
        case .limitBelowUsage: "Max Storage must be greater than zero and cannot be smaller than your completed downloads. Delete downloads first."
        case .invalidAudio(let format): "The server did not provide playable \(format.title) audio. This format may be unavailable on the server or unsupported on this device. Try another download format in Settings."
        case .http(let status): "The download server returned HTTP \(status). Check that downloading and the selected format are supported."
        }
    }
}

public struct DownloadedSong: Codable, Sendable, Identifiable {
    public let song: Song
    public let format: DownloadFormat
    public let filename: String
    public let byteCount: Int64

    public var id: Song.ID { song.id }
}

public struct DownloadStorage: Sendable {
    public let usedBytes: Int64
    public let freeBytes: Int64?
    public let songCount: Int
    public let albumCount: Int
    public let artistCount: Int
}
