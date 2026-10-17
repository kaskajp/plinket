import Foundation

/// An album as listed by `getAlbumList2`, `getArtist` and `search3`.
public struct Album: Codable, Sendable, Hashable, Identifiable {
    public let id: String
    public let name: String
    public let artist: String?
    public let artistID: String?
    public let coverArtID: String?
    public let songCount: Int?
    /// Total length in seconds.
    public let duration: Int?
    public let year: Int?
    public let genre: String?
    public let created: Date?
    public var starred: Date?
    /// Server-side sort key, e.g. with leading articles removed.
    public let sortName: String?

    public var isStarred: Bool { starred != nil }

    public init(
        id: String,
        name: String,
        artist: String? = nil,
        artistID: String? = nil,
        coverArtID: String? = nil,
        songCount: Int? = nil,
        duration: Int? = nil,
        year: Int? = nil,
        genre: String? = nil,
        created: Date? = nil,
        starred: Date? = nil,
        sortName: String? = nil
    ) {
        self.id = id
        self.name = name
        self.artist = artist
        self.artistID = artistID
        self.coverArtID = coverArtID
        self.songCount = songCount
        self.duration = duration
        self.year = year
        self.genre = genre
        self.created = created
        self.starred = starred
        self.sortName = sortName
    }

    enum CodingKeys: String, CodingKey {
        case id, name, artist, songCount, duration, year, genre, created, starred, sortName
        case artistID = "artistId"
        case coverArtID = "coverArt"
    }
}

/// An album together with its tracks, as returned by `getAlbum`.
public struct AlbumDetail: Codable, Sendable, Hashable, Identifiable {
    public let album: Album
    public let songs: [Song]

    public var id: Album.ID { album.id }

    public init(album: Album, songs: [Song]) {
        self.album = album
        self.songs = songs
    }

    public init(from decoder: any Decoder) throws {
        album = try Album(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        songs = try container.decodeIfPresent([Song].self, forKey: .songs) ?? []
    }

    public func encode(to encoder: any Encoder) throws {
        try album.encode(to: encoder)
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(songs, forKey: .songs)
    }

    enum CodingKeys: String, CodingKey {
        case songs = "song"
    }
}
