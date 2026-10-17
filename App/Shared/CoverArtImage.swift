import Library
import SwiftUI

extension EnvironmentValues {
    @Entry var imageCache: ImageCache?
}

/// Square cover art loaded through `ImageCache`, with a placeholder while loading or when art is missing.
struct CoverArtImage: View {
    let coverArtID: String?
    /// The largest size the art is drawn at, used to pick the download resolution.
    let pointSize: CGFloat
    var cornerRadius: CGFloat = 6

    @Environment(\.imageCache) private var imageCache
    @Environment(\.displayScale) private var displayScale
    @State private var image: CGImage?

    var body: some View {
        Rectangle()
            .fill(.quaternary)
            .overlay {
                if let image {
                    Image(decorative: image, scale: displayScale)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "music.note")
                        .font(.title)
                        .foregroundStyle(.secondary)
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .clipShape(.rect(cornerRadius: cornerRadius))
            .task(id: coverArtID) { await loadImage() }
    }

    private func loadImage() async {
        image = nil
        guard let coverArtID, let imageCache else { return }
        let pixelSize = Int((pointSize * displayScale).rounded(.up))
        // A failed load keeps the placeholder; cover art is decorative.
        image = try? await imageCache.image(coverArtID: coverArtID, pixelSize: pixelSize)
    }
}
