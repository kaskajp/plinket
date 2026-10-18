import Library
import Playback
import Subsonic
import SwiftUI

/// How a song row relates to the song the player is on.
enum SongPlaybackState {
    case idle, paused, playing
}

extension EnvironmentValues {
    @Entry var songPlaybackState = SongPlaybackState.idle
}

/// Plays `songs` from `index` when tapped; its context menu queues or favorites that one song.
struct PlayableSong<Label: View>: View {
    let songs: [Song]
    let index: Int
    @ViewBuilder let label: Label

    @Environment(\.playbackActions) private var playbackActions
    @Environment(PlayerController.self) private var player

    var body: some View {
        Button {
            playbackActions.play(songs, index)
        } label: {
            label
                .environment(\.songPlaybackState, playbackState)
        }
        .buttonStyle(.plain)
        .contextMenu {
            SongMenuItems(song: songs[index])
        }
    }

    private var playbackState: SongPlaybackState {
        guard player.currentSong?.id == songs[index].id else { return .idle }
        return player.isPlaying ? .playing : .paused
    }
}

/// Play Next, Add to Queue and the favorite toggle for one song.
struct SongMenuItems: View {
    let song: Song

    @Environment(LibraryStore.self) private var library
    @Environment(\.playbackActions) private var playbackActions

    var body: some View {
        Button("Play Next", systemImage: "text.line.first.and.arrowtriangle.forward") {
            playbackActions.playNext([song])
        }
        Button("Add to Queue", systemImage: "text.line.last.and.arrowtriangle.forward") {
            playbackActions.addToQueue([song])
        }
        FavoriteButton(isFavorite: library.isStarred(song)) {
            library.toggleFavorite(song)
        }
    }
}

/// A song with its cover, artist and length.
struct SongRow: View {
    private static let artworkSize: CGFloat = 40

    let song: Song

    @Environment(\.songPlaybackState) private var playbackState

    var body: some View {
        HStack(spacing: 12) {
            CoverArtImage(coverArtID: song.coverArtID, pointSize: Self.artworkSize, cornerRadius: 4)
                .frame(width: Self.artworkSize, height: Self.artworkSize)
                .overlay {
                    if playbackState != .idle {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.black.opacity(0.45))
                        NowPlayingIndicator(isPlaying: playbackState == .playing)
                            .foregroundStyle(.white)
                    }
                }
            VStack(alignment: .leading, spacing: 2) {
                SongTitle(title: song.title)
                if let artist = song.artist {
                    Text(artist)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            if let duration = song.duration {
                TrackDuration(seconds: duration)
            }
        }
        .contentShape(.rect)
    }
}

/// A track length as minutes and seconds.
struct TrackDuration: View {
    let seconds: Int

    var body: some View {
        Text(Duration.seconds(seconds), format: .time(pattern: .minuteSecond))
            .font(.subheadline.monospacedDigit())
            .foregroundStyle(.secondary)
    }
}

/// A song title that stands out in the accent color while it is the current song.
struct SongTitle: View {
    let title: String

    @Environment(\.songPlaybackState) private var playbackState

    var body: some View {
        let isCurrent = playbackState != .idle
        Text(title)
            .lineLimit(1)
            .fontWeight(isCurrent ? .semibold : nil)
            .foregroundStyle(isCurrent ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
    }
}

/// A speaker that animates while the current song plays and rests while it is paused.
struct NowPlayingIndicator: View {
    let isPlaying: Bool

    var body: some View {
        Image(systemName: "speaker.wave.2.fill")
            .symbolEffect(.variableColor.iterative.dimInactiveLayers.nonReversing, isActive: isPlaying)
            .accessibilityLabel(isPlaying ? "Now Playing" : "Paused")
    }
}
