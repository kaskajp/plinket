import Playback
import SwiftUI

/// The Controls menu. Play/Pause has no menu shortcut: Space is handled by ``SpaceBarPlayPause`` so text fields keep it.
struct PlaybackCommands: Commands {
    let player: PlayerController?

    var body: some Commands {
        CommandMenu("Controls") {
            Button(player?.isPlaying == true ? "Pause" : "Play") {
                player?.togglePlayPause()
            }
            .disabled(player?.currentSong == nil)
            Button("Next") {
                player?.next()
            }
            .keyboardShortcut(.rightArrow, modifiers: .command)
            .disabled(player?.currentSong == nil)
            Button("Previous") {
                player?.previous()
            }
            .keyboardShortcut(.leftArrow, modifiers: .command)
            .disabled(player?.currentSong == nil)
            Divider()
            if let player {
                PlaybackModeItems(player: player)
            }
        }
    }
}

private struct PlaybackModeItems: View {
    let player: PlayerController

    var body: some View {
        Toggle("Shuffle", isOn: Binding(get: { player.isShuffled }, set: { _ in player.toggleShuffle() }))
        Picker("Repeat", selection: Binding(get: { player.repeatMode }, set: player.setRepeat)) {
            ForEach(RepeatMode.allCases, id: \.self) { mode in
                Text(mode.title).tag(mode)
            }
        }
    }
}
