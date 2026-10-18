import Subsonic
import SwiftUI

/// Cover, titles and Play / Shuffle for an album or playlist; `accessory` adds buttons after them.
struct DetailHeader<Accessory: View>: View {
    private static var artworkSize: CGFloat { 320 }
    private static var actionsMaxWidth: CGFloat { 400 }

    let coverArtID: String?
    let title: String
    let subtitle: String?
    let caption: String?
    let canPlay: Bool
    let play: () -> Void
    let shuffle: () -> Void
    @ViewBuilder let accessory: Accessory

    var body: some View {
        VStack(spacing: 12) {
            CoverArtImage(coverArtID: coverArtID, pointSize: Self.artworkSize, cornerRadius: 12)
                .frame(maxWidth: Self.artworkSize)
                .shadow(radius: 8, y: 4)
            VStack(spacing: 4) {
                Text(title)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                if let subtitle {
                    Text(subtitle)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                if let caption {
                    Text(caption)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 12) {
                Group {
                    Button(action: play) {
                        Label("Play", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    // List rows tint label icons with the accent color, which hides it on a prominent button.
                    .foregroundStyle(.white)
                    .buttonStyle(.borderedProminent)
                    Button(action: shuffle) {
                        Label("Shuffle", systemImage: "shuffle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .disabled(!canPlay)
                accessory
            }
            .lineLimit(1)
            .controlSize(.large)
            .frame(maxWidth: Self.actionsMaxWidth)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical)
    }
}

extension DetailHeader where Accessory == EmptyView {
    init(
        coverArtID: String?,
        title: String,
        subtitle: String?,
        caption: String?,
        canPlay: Bool,
        play: @escaping () -> Void,
        shuffle: @escaping () -> Void
    ) {
        self.init(
            coverArtID: coverArtID,
            title: title,
            subtitle: subtitle,
            caption: caption,
            canPlay: canPlay,
            play: play,
            shuffle: shuffle,
            accessory: { EmptyView() }
        )
    }
}

extension Album {
    /// The release year, when the server knows it.
    var yearText: String? {
        guard let year, year > 0 else { return nil }
        return String(year)
    }
}

/// "12 songs · 48 min", leaving out whatever is unknown.
func songCountAndDuration(songCount: Int?, duration: Int?) -> String? {
    let songs = songCount.map { String(AttributedString(localized: "^[\($0) song](inflect: true)").characters) }
    let length = duration.flatMap { $0 > 0 ? $0 : nil }.map { Duration.seconds($0).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated)) }
    let parts = [songs, length].compactMap(\.self)
    return parts.isEmpty ? nil : parts.joined(separator: " · ")
}
