import Library
import Playback
import Subsonic
import SwiftUI

/// The player pinned to the bottom of the window.
struct PlayerBar: View {
    private static let sideWidth: CGFloat = 240

    @Binding var isShowingQueue: Bool
    @Environment(PlayerController.self) private var player
    @Environment(LibraryStore.self) private var library

    var body: some View {
        HStack(spacing: 20) {
            HStack(spacing: 10) {
                NowPlayingSummary(song: player.currentSong, error: player.error)
                if let song = player.currentSong {
                    FavoriteButton(isFavorite: library.isStarred(song)) {
                        library.toggleFavorite(song)
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.plain)
                    .foregroundStyle(library.isStarred(song) ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                }
            }
            .frame(width: Self.sideWidth, alignment: .leading)
            VStack(spacing: 4) {
                TransportControls(
                    isPlaying: player.isPlaying,
                    isEnabled: player.currentSong != nil,
                    previous: player.previous,
                    togglePlayPause: player.togglePlayPause,
                    next: player.next
                )
                .font(.title3)
                PlaybackScrubber(position: player.position, duration: player.duration, layout: .inline, seek: player.seek(to:))
                    .controlSize(.small)
            }
            .frame(maxWidth: 520)
            PlaybackOptions(
                isShuffled: player.isShuffled,
                repeatMode: player.repeatMode,
                toggleShuffle: player.toggleShuffle,
                setRepeat: player.setRepeat,
                isShowingQueue: $isShowingQueue
            )
            .frame(width: Self.sideWidth, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }
}

private struct NowPlayingSummary: View {
    private static let artworkSize: CGFloat = 44

    let song: Song?
    let error: PlaybackError?

    var body: some View {
        HStack(spacing: 10) {
            CoverArtImage(coverArtID: song?.coverArtID, pointSize: Self.artworkSize, cornerRadius: 4)
                .frame(width: Self.artworkSize, height: Self.artworkSize)
            VStack(alignment: .leading, spacing: 2) {
                Text(song?.title ?? String(localized: "Not Playing"))
                    .font(.headline)
                    .lineLimit(1)
                subtitle
                    .font(.subheadline)
                    .lineLimit(1)
            }
        }
    }

    @ViewBuilder
    private var subtitle: some View {
        if let error {
            Label("Couldn’t play “\(error.songTitle)”", systemImage: "exclamationmark.triangle")
                .foregroundStyle(.red)
                .help(error.message)
        } else if let artist = song?.artist {
            Text(artist)
                .foregroundStyle(.secondary)
        }
    }
}

private struct PlaybackOptions: View {
    let isShuffled: Bool
    let repeatMode: RepeatMode
    let toggleShuffle: () -> Void
    let setRepeat: (RepeatMode) -> Void
    @Binding var isShowingQueue: Bool

    var body: some View {
        HStack(spacing: 14) {
            Button("Shuffle", systemImage: "shuffle", action: toggleShuffle)
                .foregroundStyle(isShuffled ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                .help(isShuffled ? "Turn Shuffle Off" : "Turn Shuffle On")
            Button(repeatMode.title, systemImage: repeatMode.systemImage) {
                setRepeat(repeatMode.next)
            }
            .foregroundStyle(repeatMode == .off ? AnyShapeStyle(.secondary) : AnyShapeStyle(.tint))
            .help(repeatMode.title)
            Toggle("Queue", systemImage: "list.bullet", isOn: $isShowingQueue)
                .toggleStyle(.button)
                .help("Show Queue")
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.plain)
        .font(.title3)
    }
}
