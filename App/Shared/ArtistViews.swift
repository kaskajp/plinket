import Library
import Subsonic
import SwiftUI

/// All artists, A–Z.
struct ArtistListView: View {
    @Environment(LibraryStore.self) private var library

    var body: some View {
        content
            .navigationTitle("Artists")
            .refreshable { await library.refresh(.artists) }
    }

    @ViewBuilder
    private var content: some View {
        if library.artists.isEmpty {
            CollectionPlaceholder(
                collection: .artists,
                isRefreshing: library.isRefreshing(.artists),
                error: library.refreshError(for: .artists)
            ) {
                Task { await library.refresh(.artists) }
            }
        } else {
            ArtistIndexList(sections: ArtistIndex.sections(ofSorted: library.artists))
                .refreshErrorBanner(library.refreshError(for: .artists))
        }
    }
}

private struct ArtistIndexList: View {
    let sections: [ArtistIndexSection]

    var body: some View {
        List {
            ForEach(sections) { section in
                Section(section.title) {
                    ForEach(section.artists) { artist in
                        NavigationLink(value: artist) {
                            ArtistRow(artist: artist)
                        }
                    }
                }
                .sectionIndexLabel(section.title)
            }
        }
        #if os(iOS)
        .listSectionIndexVisibility(.visible)
        #endif
    }
}

/// An artist's picture, name and album count.
struct ArtistRow: View {
    private static let artworkSize: CGFloat = 40

    let artist: Artist

    var body: some View {
        HStack(spacing: 12) {
            CoverArtImage(coverArtID: artist.coverArtID, pointSize: Self.artworkSize, cornerRadius: Self.artworkSize / 2)
                .frame(width: Self.artworkSize, height: Self.artworkSize)
            VStack(alignment: .leading, spacing: 2) {
                Text(artist.name)
                    .lineLimit(1)
                if let albumCount = artist.albumCount {
                    Text("^[\(albumCount) album](inflect: true)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

/// An artist's albums in release order.
struct ArtistDetailView: View {
    let artist: Artist

    @Environment(LibraryStore.self) private var library
    @State private var loadError: SubsonicError?

    var body: some View {
        let detail = library.cachedArtistDetail(id: artist.id)
        let shownArtist = detail?.artist ?? artist
        content(detail)
            .navigationTitle(shownArtist.name)
            .toolbar {
                ToolbarItem {
                    FavoriteButton(isFavorite: library.isStarred(shownArtist)) {
                        library.toggleFavorite(shownArtist)
                    }
                }
            }
            .task(id: artist.id) { await loadDetail() }
    }

    @ViewBuilder
    private func content(_ detail: ArtistDetail?) -> some View {
        if let detail {
            ScrollView {
                AlbumTiles(albums: detail.albums, caption: .year)
                    .padding()
            }
        } else if let loadError {
            ContentUnavailableView("Couldn’t Load Albums", systemImage: "exclamationmark.triangle", description: Text(loadError.localizedDescription))
        } else {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func loadDetail() async {
        do {
            try await library.artistDetail(id: artist.id)
            loadError = nil
        } catch {
            loadError = error
        }
    }
}
