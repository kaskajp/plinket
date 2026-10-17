import Library
import Subsonic
import SwiftUI

/// All playlists on the server.
struct PlaylistListView: View {
    @Environment(LibraryStore.self) private var library

    var body: some View {
        content
            .navigationTitle("Playlists")
            .refreshable { await library.refresh(.playlists) }
    }

    @ViewBuilder
    private var content: some View {
        if library.playlists.isEmpty {
            CollectionPlaceholder(
                collection: .playlists,
                isRefreshing: library.isRefreshing(.playlists),
                error: library.refreshError(for: .playlists)
            ) {
                Task { await library.refresh(.playlists) }
            }
        } else {
            List(library.playlists) { playlist in
                NavigationLink(value: playlist) {
                    PlaylistRow(playlist: playlist)
                }
            }
            .refreshErrorBanner(library.refreshError(for: .playlists))
        }
    }
}

private struct PlaylistRow: View {
    private static let artworkSize: CGFloat = 56

    let playlist: Playlist

    var body: some View {
        HStack(spacing: 12) {
            CoverArtImage(coverArtID: playlist.coverArtID, pointSize: Self.artworkSize, cornerRadius: 6)
                .frame(width: Self.artworkSize, height: Self.artworkSize)
            VStack(alignment: .leading, spacing: 2) {
                Text(playlist.name)
                    .lineLimit(1)
                if let summary = songCountAndDuration(songCount: playlist.songCount, duration: playlist.duration) {
                    Text(summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

/// A playlist's header and entries; tapping an entry plays the playlist from there.
struct PlaylistDetailView: View {
    let playlist: Playlist

    @Environment(LibraryStore.self) private var library
    @Environment(\.playbackActions) private var playbackActions
    @State private var loadError: SubsonicError?

    var body: some View {
        let detail = library.cachedPlaylistDetail(id: playlist.id)
        let shownPlaylist = detail?.playlist ?? playlist
        let songs = detail?.songs ?? []
        List {
            DetailHeader(
                coverArtID: shownPlaylist.coverArtID,
                title: shownPlaylist.name,
                subtitle: shownPlaylist.comment,
                caption: songCountAndDuration(songCount: shownPlaylist.songCount, duration: shownPlaylist.duration),
                canPlay: !songs.isEmpty,
                play: { playbackActions.play(songs, 0) },
                shuffle: { playbackActions.shuffle(songs) }
            )
            .listRowSeparator(.hidden)
            if detail != nil {
                ForEach(songs.indices, id: \.self) { index in
                    PlayableSong(songs: songs, index: index) {
                        SongRow(song: songs[index])
                    }
                }
            } else if let loadError {
                ContentUnavailableView("Couldn’t Load Songs", systemImage: "exclamationmark.triangle", description: Text(loadError.localizedDescription))
                    .listRowSeparator(.hidden)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .navigationTitle(shownPlaylist.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task(id: playlist.id) { await loadDetail() }
    }

    private func loadDetail() async {
        do {
            try await library.playlistDetail(id: playlist.id)
            loadError = nil
        } catch {
            loadError = error
        }
    }
}
