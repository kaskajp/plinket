import CarPlay
import Library
import OSLog
import Playback
import Subsonic

/// The signed-in CarPlay UI: Albums, Playlists and Favorites tabs, their track lists, and Now Playing.
@MainActor
final class CarPlayLibraryBrowser {
    private static let recentAlbumCount = 100
    /// The Play and Shuffle rows above a track list.
    private static let trackListCommandCount = 2

    let rootTemplate: CPTabBarTemplate

    private let library: LibraryStore
    private let player: PlayerController
    private let interfaceController: CPInterfaceController
    private let artwork: CarPlayArtwork
    private let nowPlaying: CarPlayNowPlaying
    private let albumsList: CarPlayList
    private let playlistsList: CarPlayList
    private let favoritesList: CarPlayList
    private var observations: [Task<Void, Never>] = []

    init(session: SignedInSession, interfaceController: CPInterfaceController) {
        library = session.library
        player = session.player
        self.interfaceController = interfaceController
        let artwork = CarPlayArtwork(imageCache: session.imageCache, displayScale: interfaceController.carTraitCollection.displayScale)
        self.artwork = artwork
        nowPlaying = CarPlayNowPlaying(player: session.player, interfaceController: interfaceController, artwork: artwork)
        albumsList = Self.tab(String(localized: "Albums"), section: .albums, artwork: artwork)
        playlistsList = Self.tab(String(localized: "Playlists"), section: .playlists, artwork: artwork)
        favoritesList = Self.tab(String(localized: "Favorites"), section: .favorites, artwork: artwork)
        rootTemplate = CPTabBarTemplate(templates: [albumsList.template, playlistsList.template, favoritesList.template])
        observeLibrary()
    }

    func invalidate() {
        for observation in observations {
            observation.cancel()
        }
        observations = []
        nowPlaying.invalidate()
    }

    private static func tab(_ title: String, section: LibrarySection, artwork: CarPlayArtwork) -> CarPlayList {
        let list = CarPlayList(title: title, artwork: artwork)
        list.template.tabTitle = title
        list.template.tabImage = UIImage(systemName: section.systemImage)
        return list
    }

    // MARK: - Tabs

    private func observeLibrary() {
        let library = library
        observations = [
            observeChanges(of: { Self.recentAlbums(in: library) }) { [weak self] in self?.showAlbums($0) },
            observeChanges(of: { library.playlists }) { [weak self] in self?.showPlaylists($0) },
            observeChanges(of: { FavoritesContent(library.starred) }) { [weak self] in self?.showFavorites($0) },
            observeStatus(of: .albums, in: albumsList, emptyTitle: String(localized: "No Albums")),
            observeStatus(of: .playlists, in: playlistsList, emptyTitle: String(localized: "No Playlists")),
            observeStatus(of: .starred, in: favoritesList, emptyTitle: String(localized: "No Favorites")),
        ]
    }

    private static func recentAlbums(in library: LibraryStore) -> [Album] {
        Array(AlbumSort.recentlyAdded.sorted(library.albums).prefix(recentAlbumCount))
    }

    private func observeStatus(of collection: LibraryCollection, in list: CarPlayList, emptyTitle: String) -> Task<Void, Never> {
        let library = library
        return observeChanges(of: { CollectionStatus(collection, in: library) }) { status in
            list.setEmptyState(title: emptyTitle, message: status.errorMessage, isLoading: status.isRefreshing)
        }
    }

    private func showAlbums(_ albums: [Album]) {
        let shownAlbums = albums.prefix(CarPlayLimits.itemCount)
        let items = shownAlbums.map(albumItem)
        albumsList.show([CPListSection(items: items)], artwork: artworkRequests(items, coverArtIDs: shownAlbums.map(\.coverArtID)))
    }

    private func showPlaylists(_ playlists: [Playlist]) {
        let shownPlaylists = playlists.prefix(CarPlayLimits.itemCount)
        let items = shownPlaylists.map { playlist in
            CarPlayItems.playlist(playlist) { [weak self] in await self?.openPlaylist(playlist) }
        }
        playlistsList.show(
            [CPListSection(items: items)],
            artwork: artworkRequests(items, coverArtIDs: shownPlaylists.map(\.coverArtID))
        )
    }

    /// Albums get at most half the car's list when there are favorite songs to show too.
    private func showFavorites(_ favorites: FavoritesContent) {
        let itemLimit = CarPlayLimits.itemCount
        let albumLimit = favorites.songs.isEmpty ? itemLimit : itemLimit / 2
        let shownAlbums = favorites.albums.prefix(albumLimit)
        let shownSongs = favorites.songs.prefix(itemLimit - shownAlbums.count)
        let albumItems = shownAlbums.map(albumItem)
        let songItems = songItems(shownSongs, playing: favorites.songs)
        favoritesList.show(
            [
                CPListSection(items: albumItems, header: String(localized: "Albums"), sectionIndexTitle: nil),
                CPListSection(items: songItems, header: String(localized: "Songs"), sectionIndexTitle: nil),
            ],
            artwork: artworkRequests(albumItems, coverArtIDs: shownAlbums.map(\.coverArtID))
                + artworkRequests(songItems, coverArtIDs: shownSongs.map(\.coverArtID))
        )
    }

    // MARK: - Track lists

    private func albumItem(_ album: Album) -> CPListItem {
        CarPlayItems.album(album) { [weak self] in await self?.openAlbum(album) }
    }

    private func openAlbum(_ album: Album) async {
        do {
            let detail = try await library.albumDetail(id: album.id)
            pushTrackList(title: album.name, songs: detail.songs, showsCoverArt: false)
        } catch {
            showFailure(String(localized: "Couldn’t Load Album"), error: error)
        }
    }

    private func openPlaylist(_ playlist: Playlist) async {
        do {
            let detail = try await library.playlistDetail(id: playlist.id)
            pushTrackList(title: playlist.name, songs: detail.songs, showsCoverArt: true)
        } catch {
            showFailure(String(localized: "Couldn’t Load Playlist"), error: error)
        }
    }

    /// Album tracks share one cover, so only playlists show art per track.
    private func pushTrackList(title: String, songs: [Song], showsCoverArt: Bool) {
        let list = CarPlayList(title: title, artwork: artwork)
        list.setEmptyState(title: String(localized: "No Songs"), message: nil, isLoading: false)
        let commands = songs.isEmpty ? [] : [
            CarPlayItems.command(String(localized: "Play"), systemImage: "play.fill") { [weak self] in
                self?.play(songs, startingAt: 0)
            },
            CarPlayItems.command(String(localized: "Shuffle"), systemImage: "shuffle") { [weak self] in
                self?.shuffle(songs)
            },
        ]
        let shownSongs = songs.prefix(CarPlayLimits.itemCount - Self.trackListCommandCount)
        let trackItems = songItems(shownSongs, playing: songs)
        let artwork = showsCoverArt ? artworkRequests(trackItems, coverArtIDs: shownSongs.map(\.coverArtID)) : []
        list.show([CPListSection(items: commands + trackItems)], artwork: artwork)
        interfaceController.pushTemplate(list.template, animated: true, completion: nil)
    }

    /// Selecting one of `shownSongs` plays all of `songs` from there; `shownSongs` is a prefix of `songs`.
    private func songItems(_ shownSongs: ArraySlice<Song>, playing songs: [Song]) -> [CPListItem] {
        shownSongs.indices.map { index in
            CarPlayItems.song(songs[index]) { [weak self] in self?.play(songs, startingAt: index) }
        }
    }

    private func artworkRequests(_ items: [CPListItem], coverArtIDs: [String?]) -> [CarPlayArtwork.Request] {
        zip(items, coverArtIDs).compactMap { CarPlayArtwork.Request(item: $0, coverArtID: $1) }
    }

    // MARK: - Playback

    private func play(_ songs: [Song], startingAt index: Int) {
        player.play(songs: songs, startingAt: index)
        nowPlaying.show()
    }

    private func shuffle(_ songs: [Song]) {
        player.shuffle(songs: songs)
        nowPlaying.show()
    }

    private func showFailure(_ title: String, error: SubsonicError) {
        Logger.app.error("CarPlay: \(title): \(error)")
        let alert = CPAlertTemplate(
            titleVariants: ["\(title). \(error.localizedDescription)", title],
            actions: [
                CPAlertAction(title: String(localized: "OK"), style: .cancel) { [weak interfaceController] _ in
                    interfaceController?.dismissTemplate(animated: true, completion: nil)
                },
            ]
        )
        interfaceController.presentTemplate(alert, animated: true, completion: nil)
    }
}

/// The favorites CarPlay lists; starred artists have no CarPlay tab.
private struct FavoritesContent: Equatable, Sendable {
    let albums: [Album]
    let songs: [Song]

    init(_ starred: Starred) {
        albums = starred.albums
        songs = starred.songs
    }
}

private struct CollectionStatus: Equatable, Sendable {
    let isRefreshing: Bool
    let errorMessage: String?

    @MainActor
    init(_ collection: LibraryCollection, in library: LibraryStore) {
        isRefreshing = library.isRefreshing(collection)
        errorMessage = library.refreshError(for: collection)?.localizedDescription
    }
}
