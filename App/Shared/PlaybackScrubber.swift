import SwiftUI

/// A seek slider with elapsed and remaining time; seeks once the drag ends.
struct PlaybackScrubber: View {
    enum Layout {
        /// Times below the slider.
        case stacked
        /// Times on either side of the slider.
        case inline
    }

    let position: TimeInterval
    let duration: TimeInterval?
    var layout = Layout.stacked
    let seek: (TimeInterval) -> Void

    @State private var scrubPosition: TimeInterval?

    var body: some View {
        switch layout {
        case .stacked:
            VStack(spacing: 4) {
                slider
                HStack {
                    elapsedLabel
                    Spacer()
                    remainingLabel
                }
            }
        case .inline:
            HStack(spacing: 8) {
                elapsedLabel
                slider
                remainingLabel
            }
        }
    }

    private var displayedPosition: TimeInterval {
        scrubPosition ?? position
    }

    private var slider: some View {
        Slider(
            value: Binding(get: { displayedPosition }, set: { scrubPosition = $0 }),
            in: 0...max(duration ?? 0, 1),
            onEditingChanged: finishScrubbing
        )
        .disabled(duration == nil)
        .accessibilityLabel("Playback Position")
    }

    private var elapsedLabel: some View {
        TimeLabel(seconds: displayedPosition)
    }

    @ViewBuilder
    private var remainingLabel: some View {
        if let duration {
            TimeLabel(seconds: max(duration - displayedPosition, 0), prefix: "-")
        } else {
            TimeLabel(seconds: nil)
        }
    }

    private func finishScrubbing(isEditing: Bool) {
        guard !isEditing, let scrubPosition else { return }
        seek(scrubPosition)
        self.scrubPosition = nil
    }
}

private struct TimeLabel: View {
    let seconds: TimeInterval?
    var prefix = ""

    var body: some View {
        Group {
            if let seconds {
                Text("\(prefix)\(Duration.seconds(seconds.rounded(.down)), format: .time(pattern: .minuteSecond))")
            } else {
                Text(verbatim: "--:--")
            }
        }
        .font(.caption.monospacedDigit())
        .foregroundStyle(.secondary)
    }
}
