import Foundation

/// An album artist as listed by `getArtists` and `search3`.
public struct Artist: Codable, Sendable, Hashable, Identifiable {
    public let id: String
    public let name: String
    public let coverArtID: String?
    public let albumCount: Int?
    public var starred: Date?
    public let artistImageURL: URL?
    /// Server-side sort key, e.g. with leading articles removed.
    public let sortName: String?

    public var isStarred: Bool { starred != nil }

    public init(
        id: String,
        name: String,
        coverArtID: String? = nil,
        albumCount: Int? = nil,
        starred: Date? = nil,
        artistImageURL: URL? = nil,
        sortName: String? = nil
    ) {
        self.id = id
        self.name = name
        self.coverArtID = coverArtID
        self.albumCount = albumCount
        self.starred = starred
        self.artistImageURL = artistImageURL
        self.sortName = sortName
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        coverArtID = try container.decodeIfPresent(String.self, forKey: .coverArtID)
        albumCount = try container.decodeIfPresent(Int.self, forKey: .albumCount)
        starred = try container.decodeIfPresent(Date.self, forKey: .starred)
        // Servers without an image send an empty string, which `URL` refuses to decode.
        artistImageURL = try container.decodeIfPresent(String.self, forKey: .artistImageURL).flatMap(URL.init(string:))
        sortName = try container.decodeIfPresent(String.self, forKey: .sortName)
    }

    enum CodingKeys: String, CodingKey {
        case id, name, albumCount, starred, sortName
        case coverArtID = "coverArt"
        case artistImageURL = "artistImageUrl"
    }
}

/// An artist together with their albums, as returned by `getArtist`.
public struct ArtistDetail: Codable, Sendable, Hashable, Identifiable {
    public let artist: Artist
    public let albums: [Album]

    public var id: Artist.ID { artist.id }

    public init(artist: Artist, albums: [Album]) {
        self.artist = artist
        self.albums = albums
    }

    public init(from decoder: any Decoder) throws {
        artist = try Artist(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        albums = try container.decodeIfPresent([Album].self, forKey: .albums) ?? []
    }

    public func encode(to encoder: any Encoder) throws {
        try artist.encode(to: encoder)
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(albums, forKey: .albums)
    }

    enum CodingKeys: String, CodingKey {
        case albums = "album"
    }
}
