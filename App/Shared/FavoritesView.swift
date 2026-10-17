import Library
import Subsonic
import SwiftUI

/// Starred albums, artists and songs.
struct FavoritesView: View {
    @Environment(LibraryStore.self) private var library

    var body: some View {
        content
            .navigationTitle("Favorites")
            .refreshable { await library.refresh(.starred) }
    }

    @ViewBuilder
    private var content: some View {
        let starred = library.starred
        if starred.albums.isEmpty, starred.artists.isEmpty, starred.songs.isEmpty {
            CollectionPlaceholder(
                collection: .starred,
                isRefreshing: library.isRefreshing(.starred),
                error: library.refreshError(for: .starred)
            ) {
                Task { await library.refresh(.starred) }
            }
        } else {
            FavoritesList(albums: starred.albums, artists: starred.artists, songs: starred.songs)
                .refreshErrorBanner(library.refreshError(for: .starred))
        }
    }
}

private struct FavoritesList: View {
    let albums: [Album]
    let artists: [Artist]
    let songs: [Song]

    @Environment(\.playbackActions) private var playbackActions

    var body: some View {
        List {
            if !albums.isEmpty {
                Section("Albums") {
                    AlbumRow(albums: albums)
                        .listRowInsets(EdgeInsets())
                }
            }
            if !artists.isEmpty {
                Section("Artists") {
                    ForEach(artists) { artist in
                        NavigationLink(value: artist) {
                            ArtistRow(artist: artist)
                        }
                    }
                }
            }
            if !songs.isEmpty {
                Section {
                    ForEach(songs.indices, id: \.self) { index in
                        PlayableSong(songs: songs, index: index) {
                            SongRow(song: songs[index])
                        }
                    }
                } header: {
                    SongsHeader(play: { playbackActions.play(songs, 0) }, shuffle: { playbackActions.shuffle(songs) })
                }
            }
        }
    }
}

/// Album covers side by side, scrolling horizontally.
private struct AlbumRow: View {
    private static let tileWidth: CGFloat = 140

    let albums: [Album]

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(alignment: .top, spacing: 16) {
                ForEach(albums) { album in
                    NavigationLink(value: album) {
                        AlbumTile(album: album, caption: .artist)
                            .frame(width: Self.tileWidth)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .scrollIndicators(.hidden)
    }
}

private struct SongsHeader: View {
    let play: () -> Void
    let shuffle: () -> Void

    var body: some View {
        HStack {
            Text("Songs")
            Spacer()
            Button("Play", systemImage: "play.fill", action: play)
            Button("Shuffle", systemImage: "shuffle", action: shuffle)
        }
        .labelStyle(.iconOnly)
    }
}
