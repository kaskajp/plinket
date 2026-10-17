import Library
import Subsonic
import SwiftUI

/// Top-level destinations, shown as tabs on iOS and sidebar rows on macOS.
enum LibrarySection: String, CaseIterable, Identifiable, Hashable {
    case albums
    case artists
    case playlists
    case favorites
    case search

    static let sidebarSections: [LibrarySection] = [.albums, .artists, .playlists, .favorites]

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .albums: "Albums"
        case .artists: "Artists"
        case .playlists: "Playlists"
        case .favorites: "Favorites"
        case .search: "Search"
        }
    }

    var systemImage: String {
        switch self {
        case .albums: "square.stack"
        case .artists: "music.mic"
        case .playlists: "music.note.list"
        case .favorites: "star"
        case .search: "magnifyingglass"
        }
    }

    /// What refreshing the section fetches; search has nothing to refresh.
    var collection: LibraryCollection? {
        switch self {
        case .albums: .albums
        case .artists: .artists
        case .playlists: .playlists
        case .favorites: .starred
        case .search: nil
        }
    }
}

/// The root content of a section.
struct LibrarySectionView: View {
    let section: LibrarySection

    var body: some View {
        sectionRoot
            .libraryDestinations()
    }

    @ViewBuilder
    private var sectionRoot: some View {
        switch section {
        case .albums:
            AlbumGridView()
        case .artists:
            ArtistListView()
        case .playlists:
            PlaylistListView()
        case .favorites:
            FavoritesView()
        case .search:
            SearchView()
        }
    }
}

/// A section's navigation stack.
struct SectionNavigationStack<Root: View>: View {
    let section: LibrarySection
    @ViewBuilder let root: Root

    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            root
        }
        .opensLaunchAlbum(in: section, path: $path)
    }
}

extension View {
    /// Where albums, artists and playlists lead when tapped.
    func libraryDestinations() -> some View {
        navigationDestination(for: Album.self) { album in
            AlbumDetailView(album: album)
        }
        .navigationDestination(for: Artist.self) { artist in
            ArtistDetailView(artist: artist)
        }
        .navigationDestination(for: Playlist.self) { playlist in
            PlaylistDetailView(playlist: playlist)
        }
    }
}
