import CarPlay
import Library

/// Fills in list item images from the cover art cache, a few downloads at a time, in list order.
@MainActor
final class CarPlayArtwork {
    /// An item waiting for its cover art.
    struct Request: Sendable {
        let item: CPListItem
        let coverArtID: String

        init?(item: CPListItem, coverArtID: String?) {
            guard let coverArtID else { return nil }
            self.item = item
            self.coverArtID = coverArtID
        }
    }

    private static let concurrentLoadCount = 4

    private let imageCache: ImageCache
    private let displayScale: CGFloat

    init(imageCache: ImageCache, displayScale: CGFloat) {
        self.imageCache = imageCache
        self.displayScale = displayScale
    }

    @discardableResult
    func loadImages(_ requests: [Request]) -> Task<Void, Never> {
        let imageCache = imageCache
        let displayScale = displayScale
        let imageSize = CPListItem.maximumImageSize
        let pixelSize = Int((max(imageSize.width, imageSize.height) * displayScale).rounded(.up))
        return Task {
            await withTaskGroup(of: LoadedImage.self) { group in
                for (index, request) in requests.enumerated() {
                    if index >= Self.concurrentLoadCount, let loaded = await group.next() {
                        loaded.apply(scale: displayScale)
                    }
                    group.addTask {
                        // A failed load leaves the item without art; cover art is decorative.
                        let image = try? await imageCache.image(coverArtID: request.coverArtID, pixelSize: pixelSize)
                        return LoadedImage(item: request.item, image: image)
                    }
                }
                for await loaded in group {
                    loaded.apply(scale: displayScale)
                }
            }
        }
    }
}

private struct LoadedImage: Sendable {
    let item: CPListItem
    let image: CGImage?

    @MainActor
    func apply(scale: CGFloat) {
        guard let image else { return }
        item.setImage(UIImage(cgImage: image, scale: scale, orientation: .up))
    }
}
