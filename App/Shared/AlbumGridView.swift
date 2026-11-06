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
                    AlbumSortMenu(selection: $library.albumSort, direction: $library.albumSortDirection)
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
    @Binding var direction: AlbumSort.Direction

    var body: some View {
        Menu {
            Picker("Sort", selection: $selection) {
                ForEach(AlbumSort.allCases, id: \.self) { sort in
                    Text(sort.title).tag(sort)
                }
            }
            .pickerStyle(.inline)
            Picker("Order", selection: $direction) {
                ForEach(AlbumSort.Direction.allCases, id: \.self) { direction in
                    Text(directionTitle(direction)).tag(direction)
                }
            }
            .pickerStyle(.inline)
        } label: {
            Label {
                Text(directionTitle(direction))
            } icon: {
                Image(systemName: direction == .ascending ? "arrow.up" : "arrow.down")
            }
        }
        .accessibilityLabel(Text("Sort: \(Text(selection.title)), \(Text(directionTitle(direction)))"))
    }

    private func directionTitle(_ direction: AlbumSort.Direction) -> LocalizedStringKey {
        switch selection {
        case .title, .artist:
            direction == .ascending ? "A–Z" : "Z–A"
        case .recentlyAdded, .year:
            direction == .ascending ? "Oldest First" : "Newest First"
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
