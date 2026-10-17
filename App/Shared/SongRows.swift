import Library
import Subsonic
import SwiftUI

/// Plays `songs` from `index` when tapped; its context menu queues or favorites that one song.
struct PlayableSong<Label: View>: View {
    let songs: [Song]
    let index: Int
    @ViewBuilder let label: Label

    @Environment(\.playbackActions) private var playbackActions

    var body: some View {
        Button {
            playbackActions.play(songs, index)
        } label: {
            label
        }
        .buttonStyle(.plain)
        .contextMenu {
            SongMenuItems(song: songs[index])
        }
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

    var body: some View {
        HStack(spacing: 12) {
            CoverArtImage(coverArtID: song.coverArtID, pointSize: Self.artworkSize, cornerRadius: 4)
                .frame(width: Self.artworkSize, height: Self.artworkSize)
            VStack(alignment: .leading, spacing: 2) {
                Text(song.title)
                    .lineLimit(1)
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
