import Library
import Playback
import Subsonic
import SwiftUI

/// The full-screen player: cover, song details, scrubber, transport and queue access.
struct NowPlayingView: View {
    private static let artworkSize: CGFloat = 600

    @Environment(PlayerController.self) private var player
    @Environment(LibraryStore.self) private var library
    @Environment(\.dismiss) private var dismiss
    @State private var isShowingQueue = false

    var body: some View {
        VStack(spacing: 24) {
            CoverArtImage(coverArtID: player.currentSong?.coverArtID, pointSize: Self.artworkSize, cornerRadius: 12)
                .shadow(radius: 12, y: 6)
                .frame(maxWidth: Self.artworkSize)
            SongDetails(song: player.currentSong, error: player.error)
            PlaybackScrubber(position: player.position, duration: player.duration, seek: player.seek(to:))
            TransportControls(
                isPlaying: player.isPlaying,
                isEnabled: player.currentSong != nil,
                previous: player.previous,
                togglePlayPause: player.togglePlayPause,
                next: player.next
            )
            .font(.title)
            PlaybackOptions(
                isShuffled: player.isShuffled,
                repeatMode: player.repeatMode,
                isFavorite: player.currentSong.map(library.isStarred) ?? false,
                toggleShuffle: player.toggleShuffle,
                setRepeat: player.setRepeat,
                toggleFavorite: toggleFavorite,
                showQueue: { isShowingQueue = true }
            )
        }
        .padding(24)
        .frame(maxHeight: .infinity)
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $isShowingQueue) {
            NavigationStack {
                QueueView()
                    .navigationTitle("Queue")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            EditButton()
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { isShowingQueue = false }
                        }
                    }
            }
        }
        .onChange(of: player.currentSong == nil) { _, isEmpty in
            if isEmpty {
                dismiss()
            }
        }
    }

    private func toggleFavorite() {
        guard let song = player.currentSong else { return }
        library.toggleFavorite(song)
    }
}

private struct SongDetails: View {
    let song: Song?
    let error: PlaybackError?

    var body: some View {
        VStack(spacing: 4) {
            Text(song?.title ?? String(localized: "Not Playing"))
                .font(.title2.bold())
                .lineLimit(2)
            if let artist = song?.artist {
                Text(artist)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            if let album = song?.album {
                Text(album)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            if let error {
                Label("Couldn’t play “\(error.songTitle)”: \(error.message)", systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
        .multilineTextAlignment(.center)
    }
}

private struct PlaybackOptions: View {
    let isShuffled: Bool
    let repeatMode: RepeatMode
    let isFavorite: Bool
    let toggleShuffle: () -> Void
    let setRepeat: (RepeatMode) -> Void
    let toggleFavorite: () -> Void
    let showQueue: () -> Void

    var body: some View {
        HStack {
            Button("Shuffle", systemImage: "shuffle", action: toggleShuffle)
                .foregroundStyle(isShuffled ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                .accessibilityValue(isShuffled ? "On" : "Off")
            Spacer()
            FavoriteButton(isFavorite: isFavorite, toggle: toggleFavorite)
                .foregroundStyle(isFavorite ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
            Spacer()
            RoutePickerButton()
                .frame(width: 32, height: 32)
            Spacer()
            Button("Queue", systemImage: "list.bullet", action: showQueue)
                .foregroundStyle(.secondary)
            Spacer()
            Button(repeatMode.title, systemImage: repeatMode.systemImage) {
                setRepeat(repeatMode.next)
            }
            .foregroundStyle(repeatMode == .off ? AnyShapeStyle(.secondary) : AnyShapeStyle(.tint))
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.plain)
        .font(.title3)
    }
}
