import Foundation

/// A playlist as listed by `getPlaylists`.
public struct Playlist: Codable, Sendable, Hashable, Identifiable {
    public let id: String
    public let name: String
    public let comment: String?
    public let owner: String?
    public let isPublic: Bool?
    public let songCount: Int?
    /// Total length in seconds.
    public let duration: Int?
    public let coverArtID: String?
    public let created: Date?
    public let changed: Date?

    public init(
        id: String,
        name: String,
        comment: String? = nil,
        owner: String? = nil,
        isPublic: Bool? = nil,
        songCount: Int? = nil,
        duration: Int? = nil,
        coverArtID: String? = nil,
        created: Date? = nil,
        changed: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.comment = comment
        self.owner = owner
        self.isPublic = isPublic
        self.songCount = songCount
        self.duration = duration
        self.coverArtID = coverArtID
        self.created = created
        self.changed = changed
    }

    enum CodingKeys: String, CodingKey {
        case id, name, comment, owner, songCount, duration, created, changed
        case isPublic = "public"
        case coverArtID = "coverArt"
    }
}

/// A playlist together with its entries, as returned by `getPlaylist`.
public struct PlaylistDetail: Codable, Sendable, Hashable, Identifiable {
    public let playlist: Playlist
    public let songs: [Song]

    public var id: Playlist.ID { playlist.id }

    public init(playlist: Playlist, songs: [Song]) {
        self.playlist = playlist
        self.songs = songs
    }

    public init(from decoder: any Decoder) throws {
        playlist = try Playlist(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        songs = try container.decodeIfPresent([Song].self, forKey: .songs) ?? []
    }

    public func encode(to encoder: any Encoder) throws {
        try playlist.encode(to: encoder)
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(songs, forKey: .songs)
    }

    enum CodingKeys: String, CodingKey {
        case songs = "entry"
    }
}
