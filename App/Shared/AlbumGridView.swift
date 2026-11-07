import Library
import Subsonic
import SwiftUI

/// All albums as a cover grid, with filtering, sorting and refresh.
struct AlbumGridView: View {
    @Environment(LibraryStore.self) private var library
    @State private var isShowingFilters = false

    var body: some View {
        @Bindable var library = library
        let albums = library.filteredAlbums
        content(albums: albums)
            .navigationTitle("Albums")
            .toolbar {
                ToolbarItem {
                    Button("Filter Albums", systemImage: library.albumFilter.isActive
                           ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle") {
                        isShowingFilters = true
                    }
                }
                ToolbarItem {
                    AlbumSortMenu(selection: $library.albumSort, direction: $library.albumSortDirection)
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                if library.albumFilter.isActive {
                    HStack {
                        Text("\(albums.count) of \(library.albums.count) albums")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Clear Filters") { library.albumFilter = AlbumFilter() }
                    }
                    .padding()
                    .background(.bar)
                }
            }
            .sheet(isPresented: $isShowingFilters) {
                AlbumFilterView(
                    filter: $library.albumFilter,
                    genres: AlbumFilter.genres(in: library.albums),
                    moods: AlbumFilter.moods(in: library.albums),
                    matchingCount: albums.count
                )
            }
            .refreshable { await library.refresh(.albums) }
    }

    @ViewBuilder
    private func content(albums: [Album]) -> some View {
        if library.albums.isEmpty {
            CollectionPlaceholder(
                collection: .albums,
                isRefreshing: library.isRefreshing(.albums),
                error: library.refreshError(for: .albums)
            ) {
                Task { await library.refresh(.albums) }
            }
        } else {
            Group {
                if albums.isEmpty {
                    ContentUnavailableView {
                        Label("No Matching Albums", systemImage: "line.3.horizontal.decrease.circle")
                    } description: {
                        Text("Try changing or clearing your album filters.")
                    } actions: {
                        Button("Clear Filters") { library.albumFilter = AlbumFilter() }
                    }
                } else {
                    ScrollView {
                        AlbumTiles(albums: albums)
                            .padding()
                    }
                }
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
        case .recentlyAdded, .recentlyPlayed, .year:
            direction == .ascending ? "Oldest First" : "Newest First"
        case .rating:
            direction == .ascending ? "Lowest First" : "Highest First"
        }
    }
}

private extension AlbumSort {
    var title: LocalizedStringKey {
        switch self {
        case .recentlyAdded: "Recently Added"
        case .recentlyPlayed: "Recently Played"
        case .rating: "Rating"
        case .title: "Title"
        case .artist: "Artist"
        case .year: "Year"
        }
    }
}
