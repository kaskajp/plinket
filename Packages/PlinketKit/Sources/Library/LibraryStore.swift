import Foundation
import Observation
import Subsonic

/// A list the library fetches as a whole and caches on disk.
public enum LibraryCollection: String, CaseIterable, Sendable {
    case albums
    case artists
    case playlists
    case starred
}

/// The browsable library: shows cached snapshots immediately, then revalidates against the server.
@MainActor
@Observable
public final class LibraryStore {
    public static let defaultCacheDirectory = URL.cachesDirectory.appending(path: "Plinket/Library")
    static let albumSortDefaultsKey = "library.albumSort"

    public private(set) var albums: [Album] = []
    /// In A–Z index order, see ``ArtistIndex``.
    public private(set) var artists: [Artist] = []
    public private(set) var playlists: [Playlist] = []
    /// Everything starred. Once loaded, it decides `isStarred(_:)` for every copy of a model, wherever it is held.
    public private(set) var starred = Starred() {
        didSet { starredTargets = starred.targets }
    }
    /// The last star or unstar the server rejected; the change has already been rolled back.
    public private(set) var starError: SubsonicError?

    public var albumSort: AlbumSort {
        didSet {
            defaults.set(albumSort.rawValue, forKey: Self.albumSortDefaultsKey)
            albums = albumSort.sorted(albums)
        }
    }

    private var refreshingCollections: Set<LibraryCollection> = []
    private var refreshErrors: [LibraryCollection: SubsonicError] = [:]
    private var albumDetails = DetailCache<AlbumDetail>()
    private var artistDetails = DetailCache<ArtistDetail>()
    private var playlistDetails = DetailCache<PlaylistDetail>()
    private var starredTargets: Set<StarTarget> = []
    private var hasLoadedStarred = false
    /// Changed before starred first loaded; for these, `starred` already holds the truth.
    private var locallyChangedStarTargets: Set<StarTarget> = []

    @ObservationIgnored private let client: SubsonicClient
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let albumsFile: SnapshotFile<[Album]>
    @ObservationIgnored private let artistsFile: SnapshotFile<[Artist]>
    @ObservationIgnored private let playlistsFile: SnapshotFile<[Playlist]>
    @ObservationIgnored private let starredFile: SnapshotFile<Starred>
    @ObservationIgnored private var refreshTasks: [LibraryCollection: Task<Void, Never>] = [:]

    public init(
        client: SubsonicClient,
        cacheDirectory: URL = LibraryStore.defaultCacheDirectory,
        defaults: UserDefaults = .standard
    ) {
        self.client = client
        self.defaults = defaults
        albumsFile = SnapshotFile(directory: cacheDirectory, name: LibraryCollection.albums.rawValue)
        artistsFile = SnapshotFile(directory: cacheDirectory, name: LibraryCollection.artists.rawValue)
        playlistsFile = SnapshotFile(directory: cacheDirectory, name: LibraryCollection.playlists.rawValue)
        starredFile = SnapshotFile(directory: cacheDirectory, name: LibraryCollection.starred.rawValue)
        let savedSort = defaults.string(forKey: Self.albumSortDefaultsKey).flatMap(AlbumSort.init(rawValue:))
        self.albumSort = savedSort ?? .recentlyAdded
    }

    // MARK: - Collections

    public func isRefreshing(_ collection: LibraryCollection) -> Bool {
        refreshingCollections.contains(collection)
    }

    /// The last refresh failure; cleared by the next successful refresh. Stale data stays visible meanwhile.
    public func refreshError(for collection: LibraryCollection) -> SubsonicError? {
        refreshErrors[collection]
    }

    /// Fills each collection from disk unless a refresh already populated it.
    public func loadCachedSnapshots() async {
        async let cachedAlbums = albumsFile.load()
        async let cachedArtists = artistsFile.load()
        async let cachedPlaylists = playlistsFile.load()
        async let cachedStarred = starredFile.load()
        if let cachedAlbums = await cachedAlbums, albums.isEmpty {
            albums = albumSort.sorted(cachedAlbums)
        }
        if let cachedArtists = await cachedArtists, artists.isEmpty {
            artists = ArtistIndex.sorted(cachedArtists)
        }
        if let cachedPlaylists = await cachedPlaylists, playlists.isEmpty {
            playlists = cachedPlaylists
        }
        if let cachedStarred = await cachedStarred, !hasLoadedStarred {
            adoptLoadedStarred(cachedStarred)
        }
    }

    /// Fetches one collection. Concurrent callers share one request, which keeps running if a caller is cancelled.
    public func refresh(_ collection: LibraryCollection) async {
        if let refreshTask = refreshTasks[collection] {
            await refreshTask.value
            return
        }
        let task = Task { await fetch(collection) }
        refreshTasks[collection] = task
        await task.value
        refreshTasks[collection] = nil
    }

    public func refreshAll() async {
        await withDiscardingTaskGroup { group in
            for collection in LibraryCollection.allCases {
                group.addTask { await self.refresh(collection) }
            }
        }
    }

    // MARK: - Details

    /// The detail fetched most recently, possibly from before the last refresh.
    public func cachedAlbumDetail(id: Album.ID) -> AlbumDetail? {
        albumDetails[id]
    }

    /// Fetches the detail unless it was fetched since the last refresh; the cached one stays visible meanwhile.
    @discardableResult
    public func albumDetail(id: Album.ID) async throws(SubsonicError) -> AlbumDetail {
        if let fresh = albumDetails.freshDetail(id: id) {
            return fresh
        }
        let detail = try await client.album(id: id)
        albumDetails.insert(detail)
        return detail
    }

    public func cachedArtistDetail(id: Artist.ID) -> ArtistDetail? {
        artistDetails[id]
    }

    /// Like ``albumDetail(id:)``, with the albums in release order.
    @discardableResult
    public func artistDetail(id: Artist.ID) async throws(SubsonicError) -> ArtistDetail {
        if let fresh = artistDetails.freshDetail(id: id) {
            return fresh
        }
        let fetched = try await client.artist(id: id)
        let detail = ArtistDetail(artist: fetched.artist, albums: AlbumSort.chronological(fetched.albums))
        artistDetails.insert(detail)
        return detail
    }

    public func cachedPlaylistDetail(id: Playlist.ID) -> PlaylistDetail? {
        playlistDetails[id]
    }

    /// Like ``albumDetail(id:)``.
    @discardableResult
    public func playlistDetail(id: Playlist.ID) async throws(SubsonicError) -> PlaylistDetail {
        if let fresh = playlistDetails.freshDetail(id: id) {
            return fresh
        }
        let detail = try await client.playlist(id: id)
        playlistDetails.insert(detail)
        return detail
    }

    /// Matches across artists, albums and songs; blank text matches nothing without asking the server.
    public func search(_ text: String) async throws(SubsonicError) -> SearchResult {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return SearchResult() }
        return try await client.search(query)
    }

    // MARK: - Stars

    public func isStarred(_ song: Song) -> Bool {
        isStarred(.song(song.id), fallback: song.isStarred)
    }

    public func isStarred(_ album: Album) -> Bool {
        isStarred(.album(album.id), fallback: album.isStarred)
    }

    public func isStarred(_ artist: Artist) -> Bool {
        isStarred(.artist(artist.id), fallback: artist.isStarred)
    }

    /// Shows the change at once everywhere, then rolls it back and sets ``starError`` if the server refuses.
    public func setStarred(_ isStarred: Bool, song: Song) async {
        await setStarred(isStarred, item: .song(song))
    }

    public func setStarred(_ isStarred: Bool, album: Album) async {
        await setStarred(isStarred, item: .album(album))
    }

    public func setStarred(_ isStarred: Bool, artist: Artist) async {
        await setStarred(isStarred, item: .artist(artist))
    }

    public func dismissStarError() {
        starError = nil
    }

    /// Deletes the on-disk snapshots, e.g. on sign-out.
    public func removeCachedData() async {
        await albumsFile.remove()
        await artistsFile.remove()
        await playlistsFile.remove()
        await starredFile.remove()
    }

    // MARK: - Fetching

    private func fetch(_ collection: LibraryCollection) async {
        refreshingCollections.insert(collection)
        defer { refreshingCollections.remove(collection) }
        do {
            switch collection {
            case .albums:
                try await fetchAlbums()
            case .artists:
                try await fetchArtists()
            case .playlists:
                try await fetchPlaylists()
            case .starred:
                try await fetchStarred()
            }
            refreshErrors[collection] = nil
        } catch {
            refreshErrors[collection] = error
        }
    }

    private func fetchAlbums() async throws(SubsonicError) {
        let fetchedAlbums = try await client.allAlbums()
        albums = albumSort.sorted(fetchedAlbums)
        albumDetails.markAllStale()
        await albumsFile.save(fetchedAlbums)
    }

    private func fetchArtists() async throws(SubsonicError) {
        let fetchedArtists = try await client.artists()
        artists = ArtistIndex.sorted(fetchedArtists)
        artistDetails.markAllStale()
        await artistsFile.save(fetchedArtists)
    }

    private func fetchPlaylists() async throws(SubsonicError) {
        playlists = try await client.playlists()
        playlistDetails.markAllStale()
        await playlistsFile.save(playlists)
    }

    private func fetchStarred() async throws(SubsonicError) {
        adoptLoadedStarred(try await client.starred())
        await starredFile.save(starred)
    }

    private func adoptLoadedStarred(_ loadedStarred: Starred) {
        starred = loadedStarred
        hasLoadedStarred = true
        locallyChangedStarTargets.removeAll()
    }

    // MARK: - Starring

    private enum StarItem {
        case song(Song)
        case album(Album)
        case artist(Artist)

        var target: StarTarget {
            switch self {
            case .song(let song): .song(song.id)
            case .album(let album): .album(album.id)
            case .artist(let artist): .artist(artist.id)
            }
        }

        var ownStarDate: Date? {
            switch self {
            case .song(let song): song.starred
            case .album(let album): album.starred
            case .artist(let artist): artist.starred
            }
        }
    }

    /// Until starred has loaded, a model's own date is the best guess.
    private func starredDecides(_ target: StarTarget) -> Bool {
        hasLoadedStarred || locallyChangedStarTargets.contains(target)
    }

    private func isStarred(_ target: StarTarget, fallback: Bool) -> Bool {
        starredDecides(target) ? starredTargets.contains(target) : fallback
    }

    private func setStarred(_ isStarred: Bool, item: StarItem) async {
        let previousDate = currentStarDate(of: item)
        let wasStarred = previousDate != nil
        if wasStarred == isStarred {
            return
        }
        applyStar(isStarred ? Date.now : nil, to: item)
        do {
            try await sendStar(isStarred, target: item.target)
            starError = nil
            await starredFile.save(starred)
        } catch {
            applyStar(previousDate, to: item)
            starError = error
        }
    }

    private func currentStarDate(of item: StarItem) -> Date? {
        guard starredDecides(item.target) else { return item.ownStarDate }
        return switch item {
        case .song(let song): starred.songs.starDate(id: song.id)
        case .album(let album): starred.albums.starDate(id: album.id)
        case .artist(let artist): starred.artists.starDate(id: artist.id)
        }
    }

    private func sendStar(_ isStarred: Bool, target: StarTarget) async throws(SubsonicError) {
        if isStarred {
            try await client.star(target)
        } else {
            try await client.unstar(target)
        }
    }

    /// Writes the star date into every held copy of the item; `nil` unstars.
    private func applyStar(_ date: Date?, to item: StarItem) {
        if !hasLoadedStarred {
            locallyChangedStarTargets.insert(item.target)
        }
        switch item {
        case .song(let song):
            starred = Starred(
                artists: starred.artists,
                albums: starred.albums,
                songs: starred.songs.favorites(updating: song, starredAt: date)
            )
            albumDetails.updateAll { AlbumDetail(album: $0.album, songs: $0.songs.settingStarred(date, id: song.id)) }
            playlistDetails.updateAll {
                PlaylistDetail(playlist: $0.playlist, songs: $0.songs.settingStarred(date, id: song.id))
            }
        case .album(let album):
            albums = albums.settingStarred(date, id: album.id)
            starred = Starred(
                artists: starred.artists,
                albums: starred.albums.favorites(updating: album, starredAt: date),
                songs: starred.songs
            )
            albumDetails.updateAll { AlbumDetail(album: $0.album.settingStarred(date, ifID: album.id), songs: $0.songs) }
            artistDetails.updateAll { ArtistDetail(artist: $0.artist, albums: $0.albums.settingStarred(date, id: album.id)) }
        case .artist(let artist):
            artists = artists.settingStarred(date, id: artist.id)
            starred = Starred(
                artists: starred.artists.favorites(updating: artist, starredAt: date),
                albums: starred.albums,
                songs: starred.songs
            )
            artistDetails.updateAll { ArtistDetail(artist: $0.artist.settingStarred(date, ifID: artist.id), albums: $0.albums) }
        }
    }
}
