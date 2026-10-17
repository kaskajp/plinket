import Foundation

/// Matches returned by `search3`.
public struct SearchResult: Codable, Sendable, Hashable {
    public let artists: [Artist]
    public let albums: [Album]
    public let songs: [Song]

    public init(artists: [Artist] = [], albums: [Album] = [], songs: [Song] = []) {
        self.artists = artists
        self.albums = albums
        self.songs = songs
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        artists = try container.decodeIfPresent([Artist].self, forKey: .artists) ?? []
        albums = try container.decodeIfPresent([Album].self, forKey: .albums) ?? []
        songs = try container.decodeIfPresent([Song].self, forKey: .songs) ?? []
    }

    enum CodingKeys: String, CodingKey {
        case artists = "artist"
        case albums = "album"
        case songs = "song"
    }
}

/// Everything the user has starred, as returned by `getStarred2`.
public struct Starred: Codable, Sendable, Hashable {
    public let artists: [Artist]
    public let albums: [Album]
    public let songs: [Song]

    public init(artists: [Artist] = [], albums: [Album] = [], songs: [Song] = []) {
        self.artists = artists
        self.albums = albums
        self.songs = songs
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        artists = try container.decodeIfPresent([Artist].self, forKey: .artists) ?? []
        albums = try container.decodeIfPresent([Album].self, forKey: .albums) ?? []
        songs = try container.decodeIfPresent([Song].self, forKey: .songs) ?? []
    }

    enum CodingKeys: String, CodingKey {
        case artists = "artist"
        case albums = "album"
        case songs = "song"
    }
}
