import Feedback
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct ReportScreenshot: Identifiable {
    static let maximumInputBytes = 20 * 1024 * 1024
    private static let maximumDimension = 1600

    let id = UUID()
    let data: Data
    let image: CGImage

    init(data: Data) throws {
        guard data.count <= Self.maximumInputBytes else { throw ScreenshotError.tooLarge }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: Self.maximumDimension,
              ] as CFDictionary) else { throw ScreenshotError.unreadable }
        let encoded = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(encoded, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw ScreenshotError.unreadable
        }
        // Re-encoding pixels avoids sending photo location and other source metadata.
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.8] as CFDictionary)
        guard CGImageDestinationFinalize(destination), encoded.length <= ProblemReport.maximumScreenshotBytes else {
            throw ScreenshotError.tooLarge
        }
        self.data = encoded as Data
        self.image = image
    }
}

enum ScreenshotError: LocalizedError {
    case unreadable
    case tooLarge
    case tooMany

    var errorDescription: String? {
        switch self {
        case .unreadable: String(localized: "This image could not be read. Choose a PNG or JPEG screenshot.")
        case .tooLarge: String(localized: "This image is too large. Choose a smaller screenshot (up to 20 MB before resizing).")
        case .tooMany: String(localized: "You can attach up to three screenshots.")
        }
    }
}
