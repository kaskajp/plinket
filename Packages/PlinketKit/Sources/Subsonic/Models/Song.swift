import Foundation

/// A single track.
public struct Song: Codable, Sendable, Hashable, Identifiable {
    public let id: String
    public let title: String
    public let album: String?
    public let albumID: String?
    public let artist: String?
    public let artistID: String?
    public let track: Int?
    public let discNumber: Int?
    public let year: Int?
    /// Length in seconds.
    public let duration: Int?
    public let coverArtID: String?
    public let suffix: String?
    public let contentType: String?
    /// Bit rate in kbps.
    public let bitRate: Int?
    /// File size in bytes.
    public let size: Int64?
    public var starred: Date?

    public var isStarred: Bool { starred != nil }

    public init(
        id: String,
        title: String,
        album: String? = nil,
        albumID: String? = nil,
        artist: String? = nil,
        artistID: String? = nil,
        track: Int? = nil,
        discNumber: Int? = nil,
        year: Int? = nil,
        duration: Int? = nil,
        coverArtID: String? = nil,
        suffix: String? = nil,
        contentType: String? = nil,
        bitRate: Int? = nil,
        size: Int64? = nil,
        starred: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.album = album
        self.albumID = albumID
        self.artist = artist
        self.artistID = artistID
        self.track = track
        self.discNumber = discNumber
        self.year = year
        self.duration = duration
        self.coverArtID = coverArtID
        self.suffix = suffix
        self.contentType = contentType
        self.bitRate = bitRate
        self.size = size
        self.starred = starred
    }

    enum CodingKeys: String, CodingKey {
        case id, title, album, artist, track, discNumber, year, duration, suffix, contentType, bitRate, size, starred
        case albumID = "albumId"
        case artistID = "artistId"
        case coverArtID = "coverArt"
    }
}
