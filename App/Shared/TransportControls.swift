import SwiftUI

/// Previous, play/pause and next buttons.
struct TransportControls: View {
    let isPlaying: Bool
    let isBuffering: Bool
    let isEnabled: Bool
    let previous: () -> Void
    let togglePlayPause: () -> Void
    let next: () -> Void

    var body: some View {
        HStack(spacing: 24) {
            Button("Previous", systemImage: "backward.fill", action: previous)
            PlayPauseButton(isPlaying: isPlaying, isBuffering: isBuffering, action: togglePlayPause)
                .font(.largeTitle)
            Button("Next", systemImage: "forward.fill", action: next)
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

/// Shows "pause" while playing and "play" otherwise.
struct PlayPauseButton: View {
    let isPlaying: Bool
    let isBuffering: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                // The glyphs differ by a point, so both reserve space to keep the button, and the bar around it, one size.
                Label("Play", systemImage: "play.fill").hidden()
                Label("Pause", systemImage: "pause.fill").hidden()
                if isPlaying {
                    Label("Pause", systemImage: "pause.fill")
                } else {
                    Label("Play", systemImage: "play.fill")
                }
            }
        }
        .contentTransition(.symbolEffect(.replace))
        .accessibilityLabel(isPlaying ? Text("Pause") : Text("Play"))
        .accessibilityValue(isBuffering ? Text("Buffering") : Text(""))
        .overlay(alignment: .trailing) {
            if isBuffering {
                ProgressView()
                    .controlSize(.mini)
                    .frame(width: 12, height: 12)
                    .offset(x: 18)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .padding(.trailing, 18)
    }
}
