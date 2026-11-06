import AVFoundation
import Foundation
import Subsonic
import Synchronization

struct DownloadTransfer {
    static func fetch(
        from source: URL, to destination: URL, maximumBytes: Int64, allowsCellular: Bool,
        format: DownloadFormat
    ) async throws {
        let configuration = URLSessionConfiguration.default
        configuration.allowsCellularAccess = allowsCellular
        configuration.allowsExpensiveNetworkAccess = allowsCellular
        configuration.urlCache = nil
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 3_600
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let delegate = SizeLimitDelegate(maximumBytes: maximumBytes)
        var request = URLRequest(url: source)
        request.allowsCellularAccess = allowsCellular
        request.allowsExpensiveNetworkAccess = allowsCellular
        let temporary: URL
        let response: URLResponse
        do {
            (temporary, response) = try await session.download(for: request, delegate: delegate)
        } catch {
            if delegate.exceededLimit { throw DownloadError.insufficientSpace }
            throw error
        }
        defer { try? FileManager.default.removeItem(at: temporary) }
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw DownloadError.http((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        let bytes = Int64(try temporary.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0)
        guard bytes <= maximumBytes else { throw DownloadError.insufficientSpace }
        guard bytes > 0 else { throw DownloadError.invalidAudio(format) }
        try FileManager.default.moveItem(at: temporary, to: destination)
        do {
            try await validateAudio(at: destination, format: format)
        } catch {
            try? FileManager.default.removeItem(at: destination)
            try Task.checkCancellation()
            throw DownloadError.invalidAudio(format)
        }
    }

    static func validateAudio(at url: URL, format: DownloadFormat) async throws {
        let asset = AVURLAsset(url: url)
        guard try await asset.load(.isPlayable) else { throw DownloadError.invalidAudio(format) }
        let tracks = try await asset.loadTracks(withMediaType: .audio)
        guard let track = tracks.first else { throw DownloadError.invalidAudio(format) }
        guard format != .original else { return }
        let descriptions = try await track.load(.formatDescriptions)
        let expected = format == .mp3 ? kAudioFormatMPEGLayer3 : kAudioFormatOpus
        guard descriptions.contains(where: { CMFormatDescriptionGetMediaSubType($0) == expected }) else {
            throw DownloadError.invalidAudio(format)
        }
    }
}

private final class SizeLimitDelegate: NSObject, URLSessionDownloadDelegate, Sendable {
    let maximumBytes: Int64
    private let exceeded = Mutex(false)

    var exceededLimit: Bool { exceeded.withLock { $0 } }

    init(maximumBytes: Int64) {
        self.maximumBytes = maximumBytes
    }

    func urlSession(
        _ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64
    ) {
        guard totalBytesWritten > maximumBytes || totalBytesExpectedToWrite > maximumBytes else { return }
        exceeded.withLock { $0 = true }
        downloadTask.cancel()
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {}
}
