import Foundation
import Library
import Subsonic
import Testing

struct ImageCacheTests {
    private let directory = makeTemporaryDirectory()

    @Test func image_downsamplesToRequestedBucket() async throws {
        let png = pngData(width: 1000, height: 1000)
        let cache = makeStubbedImageCache(directory: directory) { _ in StubURLProtocol.StubResponse(body: png) }

        let image = try await cache.image(coverArtID: "al-1", pixelSize: 200)

        #expect(image.width == 256)
    }

    @Test func image_sharesOneDownloadBetweenConcurrentRequests() async throws {
        let recorder = RequestRecorder()
        let png = pngData(width: 300, height: 300)
        let cache = makeStubbedImageCache(directory: directory) { request in
            recorder.record(request)
            return StubURLProtocol.StubResponse(body: png)
        }

        async let first = cache.image(coverArtID: "al-1", pixelSize: 256)
        async let second = cache.image(coverArtID: "al-1", pixelSize: 256)
        _ = try await (first, second)

        #expect(recorder.urls.count == 1)
    }

    @Test func image_isServedFromDiskAfterRelaunch() async throws {
        let png = pngData(width: 300, height: 300)
        let onlineCache = makeStubbedImageCache(directory: directory) { _ in StubURLProtocol.StubResponse(body: png) }
        _ = try await onlineCache.image(coverArtID: "al-1", pixelSize: 256)
        let relaunchedOfflineCache = makeStubbedImageCache(directory: directory) { _ in
            StubURLProtocol.StubResponse(statusCode: 503)
        }

        let image = try await relaunchedOfflineCache.image(coverArtID: "al-1", pixelSize: 256)

        #expect(image.width == 256)
    }
}
