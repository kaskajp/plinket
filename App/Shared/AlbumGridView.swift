import Library
import Subsonic
import SwiftUI

/// All albums as a cover grid, with sorting and refresh.
struct AlbumGridView: View {
    @Environment(LibraryStore.self) private var library

    var body: some View {
        @Bindable var library = library
        content
            .navigationTitle("Albums")
            .toolbar {
                ToolbarItem {
                    AlbumSortMenu(selection: $library.albumSort)
                }
            }
            .refreshable { await library.refresh(.albums) }
    }

    @ViewBuilder
    private var content: some View {
        if library.albums.isEmpty {
            CollectionPlaceholder(
                collection: .albums,
                isRefreshing: library.isRefreshing(.albums),
                error: library.refreshError(for: .albums)
            ) {
                Task { await library.refresh(.albums) }
            }
        } else {
            ScrollView {
                AlbumTiles(albums: library.albums)
                    .padding()
            }
            .refreshErrorBanner(library.refreshError(for: .albums))
        }
    }
}

/// Album covers in an adaptive grid, each opening its album.
struct AlbumTiles: View {
    private static let columns = [GridItem(.adaptive(minimum: 150, maximum: AlbumTile.maximumWidth), spacing: 16)]

    let albums: [Album]
    var caption = AlbumTile.Caption.artist

    var body: some View {
        LazyVGrid(columns: Self.columns, alignment: .leading, spacing: 20) {
            ForEach(albums) { album in
                NavigationLink(value: album) {
                    AlbumTile(album: album, caption: caption)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// An album cover with its title and a caption below.
struct AlbumTile: View {
    enum Caption {
        case artist
        case year
    }

    static let maximumWidth: CGFloat = 220

    let album: Album
    let caption: Caption

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            CoverArtImage(coverArtID: album.coverArtID, pointSize: Self.maximumWidth)
            VStack(alignment: .leading, spacing: 2) {
                Text(album.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                if let captionText {
                    Text(captionText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .contentShape(.rect)
    }

    private var captionText: String? {
        switch caption {
        case .artist: album.artist
        case .year: album.yearText
        }
    }
}

private struct AlbumSortMenu: View {
    @Binding var selection: AlbumSort

    var body: some View {
        Menu("Sort", systemImage: "arrow.up.arrow.down") {
            Picker("Sort", selection: $selection) {
                ForEach(AlbumSort.allCases, id: \.self) { sort in
                    Text(sort.title).tag(sort)
                }
            }
            .pickerStyle(.inline)
        }
    }
}

private extension AlbumSort {
    var title: LocalizedStringKey {
        switch self {
        case .recentlyAdded: "Recently Added"
        case .title: "Title"
        case .artist: "Artist"
        case .year: "Year"
        }
    }
}
