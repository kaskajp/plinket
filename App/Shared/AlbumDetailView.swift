import Library
import Subsonic
import SwiftUI

/// An album's header and track list; tapping a track plays the album from there.
struct AlbumDetailView: View {
    let album: Album

    @Environment(LibraryStore.self) private var library
    @Environment(\.playbackActions) private var playbackActions
    @State private var loadError: SubsonicError?

    var body: some View {
        let detail = library.cachedAlbumDetail(id: album.id)
        let shownAlbum = detail?.album ?? album
        let songs = detail?.songs ?? []
        List {
            DetailHeader(
                coverArtID: shownAlbum.coverArtID,
                title: shownAlbum.name,
                subtitle: shownAlbum.artist,
                caption: shownAlbum.yearText,
                canPlay: !songs.isEmpty,
                play: { playbackActions.play(songs, 0) },
                shuffle: { playbackActions.shuffle(songs) }
            ) {
                FavoriteButton(isFavorite: library.isStarred(shownAlbum)) {
                    library.toggleFavorite(shownAlbum)
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
            }
            .listRowSeparator(.hidden)
            if let detail {
                AlbumTracks(detail: detail)
            } else if let loadError {
                ContentUnavailableView("Couldn’t Load Tracks", systemImage: "exclamationmark.triangle", description: Text(loadError.localizedDescription))
                    .listRowSeparator(.hidden)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .navigationTitle(shownAlbum.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task(id: album.id) { await loadDetail() }
    }

    private func loadDetail() async {
        do {
            try await library.albumDetail(id: album.id)
            loadError = nil
        } catch {
            loadError = error
        }
    }
}

/// The track list, under "Disc 1", "Disc 2"… headers when the album spans several discs.
private struct AlbumTracks: View {
    let detail: AlbumDetail

    var body: some View {
        let discs = detail.discs
        if discs.count > 1 {
            ForEach(discs) { disc in
                Section("Disc \(disc.number)") {
                    trackRows(disc.songIndices)
                }
            }
        } else {
            trackRows(Array(detail.songs.indices))
        }
    }

    private func trackRows(_ songIndices: [Int]) -> some View {
        ForEach(songIndices, id: \.self) { index in
            let song = detail.songs[index]
            PlayableSong(songs: detail.songs, index: index) {
                TrackRow(
                    number: song.track ?? index + 1,
                    title: song.title,
                    artist: song.artist == detail.album.artist ? nil : song.artist,
                    duration: song.duration
                )
            }
        }
    }
}

private struct TrackRow: View {
    let number: Int
    let title: String
    let artist: String?
    let duration: Int?

    @Environment(\.songPlaybackState) private var playbackState

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if playbackState == .idle {
                    Text(String(number))
                        .foregroundStyle(.secondary)
                } else {
                    NowPlayingIndicator(isPlaying: playbackState == .playing)
                        .foregroundStyle(.tint)
                }
            }
            .font(.subheadline.monospacedDigit())
            .frame(minWidth: 24, alignment: .trailing)
            VStack(alignment: .leading, spacing: 2) {
                SongTitle(title: title)
                if let artist {
                    Text(artist)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            if let duration {
                TrackDuration(seconds: duration)
            }
        }
        .contentShape(.rect)
    }
}
