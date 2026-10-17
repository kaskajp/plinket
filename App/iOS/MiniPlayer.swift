import Subsonic
import SwiftUI

/// The compact player in the tab bar accessory; tapping the song opens Now Playing.
struct MiniPlayer: View {
    private static let artworkSize: CGFloat = 32

    let song: Song
    let isPlaying: Bool
    let open: () -> Void
    let togglePlayPause: () -> Void
    let next: () -> Void

    @Environment(\.tabViewBottomAccessoryPlacement) private var placement

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                CoverArtImage(coverArtID: song.coverArtID, pointSize: Self.artworkSize, cornerRadius: 4)
                    .frame(width: Self.artworkSize, height: Self.artworkSize)
                VStack(alignment: .leading, spacing: 0) {
                    Text(song.title)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                    if let artist = song.artist {
                        Text(artist)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
            .contentShape(.rect)
            .onTapGesture(perform: open)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(named: "Open Now Playing", open)
            PlayPauseButton(isPlaying: isPlaying, action: togglePlayPause)
            if placement != .inline {
                Button("Next", systemImage: "forward.fill", action: next)
            }
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.plain)
        .font(.title3)
        .padding(.horizontal)
    }
}
