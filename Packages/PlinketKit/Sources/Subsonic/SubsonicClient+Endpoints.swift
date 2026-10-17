import Foundation

/// Orderings supported by `getAlbumList2`.
public enum AlbumListType: Sendable, Hashable {
    case newest
    case alphabeticalByName
    case alphabeticalByArtist
    case recent
    case byYear(from: Int, to: Int)

    var queryItems: [URLQueryItem] {
        switch self {
        case .newest:
            [URLQueryItem(name: QueryName.type, value: "newest")]
        case .alphabeticalByName:
            [URLQueryItem(name: QueryName.type, value: "alphabeticalByName")]
        case .alphabeticalByArtist:
            [URLQueryItem(name: QueryName.type, value: "alphabeticalByArtist")]
        case .recent:
            [URLQueryItem(name: QueryName.type, value: "recent")]
        case .byYear(let fromYear, let toYear):
            [
                URLQueryItem(name: QueryName.type, value: "byYear"),
                URLQueryItem(name: QueryName.fromYear, value: String(fromYear)),
                URLQueryItem(name: QueryName.toYear, value: String(toYear)),
            ]
        }
    }
}

/// Something that can be starred or unstarred.
public enum StarTarget: Sendable, Hashable {
    case song(Song.ID)
    case album(Album.ID)
    case artist(Artist.ID)

    var queryItem: URLQueryItem {
        switch self {
        case .song(let id):
            URLQueryItem(name: QueryName.id, value: id)
        case .album(let id):
            URLQueryItem(name: QueryName.albumID, value: id)
        case .artist(let id):
            URLQueryItem(name: QueryName.artistID, value: id)
        }
    }
}

extension SubsonicClient {
    public static let maximumAlbumListPageSize = 500

    /// Succeeds when the server is reachable and accepts the credentials.
    public func ping() async throws(SubsonicError) {
        try await perform(.ping)
    }

    public func albumList(
        _ type: AlbumListType,
        size: Int = maximumAlbumListPageSize,
        offset: Int = 0
    ) async throws(SubsonicError) -> [Album] {
        let pageSize = min(max(size, 1), Self.maximumAlbumListPageSize)
        let query = type.queryItems + [
            URLQueryItem(name: QueryName.size, value: String(pageSize)),
            URLQueryItem(name: QueryName.offset, value: String(offset)),
        ]
        let payload: AlbumListPayload = try await payload(.getAlbumList2, query: query)
        return payload.album ?? []
    }

    /// Pages through `getAlbumList2` until the server runs out of albums.
    public func allAlbums(_ type: AlbumListType = .alphabeticalByName) async throws(SubsonicError) -> [Album] {
        var albums: [Album] = []
        while true {
            let page = try await albumList(type, size: Self.maximumAlbumListPageSize, offset: albums.count)
            albums += page
            if page.count < Self.maximumAlbumListPageSize {
                return albums
            }
        }
    }

    public func album(id: Album.ID) async throws(SubsonicError) -> AlbumDetail {
        try await payload(.getAlbum, query: [URLQueryItem(name: QueryName.id, value: id)])
    }

    /// All artists, flattened out of the server's alphabetical index.
    public func artists() async throws(SubsonicError) -> [Artist] {
        let payload: ArtistIndexesPayload = try await payload(.getArtists)
        return (payload.index ?? []).flatMap { $0.artist ?? [] }
    }

    public func artist(id: Artist.ID) async throws(SubsonicError) -> ArtistDetail {
        try await payload(.getArtist, query: [URLQueryItem(name: QueryName.id, value: id)])
    }

    public func search(
        _ text: String,
        artistCount: Int = 20,
        albumCount: Int = 20,
        songCount: Int = 50
    ) async throws(SubsonicError) -> SearchResult {
        try await payload(.search3, query: [
            URLQueryItem(name: QueryName.query, value: text),
            URLQueryItem(name: QueryName.artistCount, value: String(artistCount)),
            URLQueryItem(name: QueryName.albumCount, value: String(albumCount)),
            URLQueryItem(name: QueryName.songCount, value: String(songCount)),
        ])
    }

    public func playlists() async throws(SubsonicError) -> [Playlist] {
        let payload: PlaylistsPayload = try await payload(.getPlaylists)
        return payload.playlist ?? []
    }

    public func playlist(id: Playlist.ID) async throws(SubsonicError) -> PlaylistDetail {
        try await payload(.getPlaylist, query: [URLQueryItem(name: QueryName.id, value: id)])
    }

    public func starred() async throws(SubsonicError) -> Starred {
        try await payload(.getStarred2)
    }

    public func star(_ target: StarTarget) async throws(SubsonicError) {
        try await perform(.star, query: [target.queryItem])
    }

    public func unstar(_ target: StarTarget) async throws(SubsonicError) {
        try await perform(.unstar, query: [target.queryItem])
    }

    /// Reports playback; `submission: false` marks "now playing", `true` records a finished listen.
    public func scrobble(songID: Song.ID, playedAt: Date, submission: Bool) async throws(SubsonicError) {
        let millisecondsSince1970 = Int64((playedAt.timeIntervalSince1970 * 1000).rounded())
        try await perform(.scrobble, query: [
            URLQueryItem(name: QueryName.id, value: songID),
            URLQueryItem(name: QueryName.time, value: String(millisecondsSince1970)),
            URLQueryItem(name: QueryName.submission, value: String(submission)),
        ])
    }

    /// The original file, never transcoded.
    public nonisolated func streamURL(songID: Song.ID) -> URL {
        url(for: .stream, query: [
            URLQueryItem(name: QueryName.id, value: songID),
            URLQueryItem(name: QueryName.streamFormat, value: QueryValue.rawStream),
        ])
    }

    /// Cover art scaled server-side to `size` pixels, or the original when `size` is `nil`.
    public nonisolated func coverArtURL(id: String, size: Int? = nil) -> URL {
        var query = [URLQueryItem(name: QueryName.id, value: id)]
        if let size {
            query.append(URLQueryItem(name: QueryName.size, value: String(size)))
        }
        return url(for: .getCoverArt, query: query)
    }
}
