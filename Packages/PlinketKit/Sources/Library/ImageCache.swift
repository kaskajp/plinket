import CoreGraphics
import Foundation
import ImageIO
import OSLog
import Subsonic

/// The cover art could not be fetched or decoded.
public enum ImageCacheError: Error, Sendable {
    case http(statusCode: Int)
    case undecodableImage
}

/// Cover art cache: decoded images in memory, downloaded bytes on disk, one download per image at a time.
public actor ImageCache {
    public static let defaultDirectory = URL.cachesDirectory.appending(path: "Plinket/CoverArt")
    /// Requested sizes snap up to these so nearby view sizes share one cached file.
    static let pixelSizeBuckets = [128, 256, 512, 1024]
    public static let defaultSession: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 30
        return URLSession(configuration: configuration)
    }()
    private static let successStatusCodes = 200..<300

    private let client: SubsonicClient
    private let directory: URL
    private let session: URLSession
    private let memoryCache = NSCache<NSString, CGImage>()
    private var inFlightLoads: [String: Task<CGImage, any Error>] = [:]

    public init(client: SubsonicClient, directory: URL = ImageCache.defaultDirectory, session: URLSession = ImageCache.defaultSession) {
        self.client = client
        self.directory = directory
        self.session = session
    }

    /// Returns cover art no larger than `pixelSize` on its longest edge.
    public func image(coverArtID: String, pixelSize: Int) async throws -> CGImage {
        let bucketedSize = Self.bucketedPixelSize(pixelSize)
        let cacheKey = "\(coverArtID)_\(bucketedSize)"
        if let cached = memoryCache.object(forKey: cacheKey as NSString) {
            return cached
        }
        if let inFlightLoad = inFlightLoads[cacheKey] {
            return try await inFlightLoad.value
        }
        let request = ImageRequest(
            remoteURL: client.coverArtURL(id: coverArtID, size: bucketedSize),
            fileURL: directory.appending(path: Self.fileName(for: cacheKey)),
            pixelSize: bucketedSize
        )
        let session = session
        let load = Task { try await Self.loadImage(request, session: session) }
        inFlightLoads[cacheKey] = load
        defer { inFlightLoads[cacheKey] = nil }
        let image = try await load.value
        memoryCache.setObject(image, forKey: cacheKey as NSString)
        return image
    }

    /// Drops every cached image from memory and disk, e.g. on sign-out.
    public func removeAll() async {
        memoryCache.removeAllObjects()
        await Self.removeDirectory(directory)
    }

    static func bucketedPixelSize(_ pixelSize: Int) -> Int {
        pixelSizeBuckets.first { $0 >= pixelSize } ?? pixelSizeBuckets[pixelSizeBuckets.count - 1]
    }

    private static func fileName(for cacheKey: String) -> String {
        cacheKey.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? cacheKey
    }

    private struct ImageRequest: Sendable {
        let remoteURL: URL
        let fileURL: URL
        let pixelSize: Int
    }

    @concurrent
    private static func loadImage(_ request: ImageRequest, session: URLSession) async throws -> CGImage {
        if let cachedData = try? Data(contentsOf: request.fileURL),
           let image = downsampledImage(from: cachedData, maxPixelSize: request.pixelSize) {
            return image
        }
        let (data, response) = try await session.data(from: request.remoteURL)
        if let httpResponse = response as? HTTPURLResponse, !successStatusCodes.contains(httpResponse.statusCode) {
            throw ImageCacheError.http(statusCode: httpResponse.statusCode)
        }
        guard let image = downsampledImage(from: data, maxPixelSize: request.pixelSize) else {
            throw ImageCacheError.undecodableImage
        }
        writeToDisk(data, at: request.fileURL)
        return image
    }

    private static func downsampledImage(from data: Data, maxPixelSize: Int) -> CGImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else { return nil }
        let thumbnailOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ] as CFDictionary
        return CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions)
    }

    private static func writeToDisk(_ data: Data, at fileURL: URL) {
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            Logger.library.error("Could not cache cover art: \(error)")
        }
    }

    @concurrent
    private static func removeDirectory(_ directory: URL) async {
        do {
            try FileManager.default.removeItem(at: directory)
        } catch CocoaError.fileNoSuchFile {
            return
        } catch {
            Logger.library.error("Could not clear cover art cache: \(error)")
        }
    }
}
