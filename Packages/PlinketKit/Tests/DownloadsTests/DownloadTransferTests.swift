import AVFoundation
import Foundation
import Network
import Playback
import Subsonic
import Testing
@testable import Downloads

struct DownloadTransferTests {
    @Test func requestedMP3IsAcceptedAndStoredAsReceived() async throws {
        let fixture = try #require(Bundle.module.url(forResource: "silence-mp3", withExtension: "base64", subdirectory: "Fixtures"))
        let audio = try #require(Data(base64Encoded: Data(contentsOf: fixture), options: .ignoreUnknownCharacters))
        let server = try await AudioServer.start(body: audio)
        defer { server.stop() }
        let destination = FileManager.default.temporaryDirectory.appending(path: "SelectedMP3-\(UUID()).mp3")
        defer { try? FileManager.default.removeItem(at: destination) }

        try await DownloadTransfer.fetch(from: server.url, to: destination, maximumBytes: 1_000_000, allowsCellular: false, format: .mp3)

        #expect(try Data(contentsOf: destination) == audio)
    }

    @Test(.timeLimit(.minutes(1))) @MainActor
    func realDownloadPlaysAfterRestoringWithServerStopped() async throws {
        let audio = waveAudio()
        let server = try await AudioServer.start(body: audio)
        defer { server.stop() }
        let directory = FileManager.default.temporaryDirectory.appending(path: "PlinketOfflineTests-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = server.url
        let manager = DownloadManager(
            directory: directory, sourceURL: { _, _ in source },
            transfer: { try await DownloadTransfer.fetch(from: $0, to: $1, maximumBytes: $2, allowsCellular: $3, format: $4) },
            freeSpace: { _ in 1_000_000_000 }
        )
        manager.updateSettings(DownloadSettings(format: .original))
        manager.updateNetwork(isConnected: true, isCellular: false)
        manager.enqueue([Song(id: "offline", title: "Offline", albumID: "album", artistID: "artist", suffix: "wav")])
        await manager.waitUntilIdle()
        #expect(manager.errorMessage == nil)
        #expect(manager.storage.usedBytes == Int64(audio.count))
        server.stop()

        let restored = DownloadManager(
            directory: directory, sourceURL: { _, _ in source },
            transfer: { _, _, _, _, _ in Issue.record("Offline playback must not download") },
            freeSpace: { _ in 1_000_000_000 }
        )
        let local = try #require(restored.localURL(for: "offline"))
        #expect(try Data(contentsOf: local) == audio)
        let engine = QueuePlayerEngine()
        defer { engine.stop() }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            engine.onEvent = { event in
                switch event {
                case .reachedEnd:
                    engine.onEvent = nil
                    continuation.resume()
                case .failed(_, let message):
                    engine.onEvent = nil
                    continuation.resume(throwing: NSError(domain: "OfflinePlayback", code: 1, userInfo: [NSLocalizedDescriptionKey: message]))
                default:
                    break
                }
            }
            engine.load(PlaybackItem(id: UUID(), url: local), startingAt: 0, next: nil)
            engine.play()
        }
        await restored.deleteAll()
        #expect(!FileManager.default.fileExists(atPath: local.path))
        #expect(restored.storage.usedBytes == 0)
    }

    @Test(arguments: [DownloadFormat.mp3, .opus])
    func serverIgnoringSelectedFormatIsRejected(format: DownloadFormat) async throws {
        let server = try await AudioServer.start(body: waveAudio())
        defer { server.stop() }
        let destination = FileManager.default.temporaryDirectory.appending(path: "WrongFormat-\(UUID()).\(format.rawValue)")
        defer { try? FileManager.default.removeItem(at: destination) }

        await #expect(throws: DownloadError.self) {
            try await DownloadTransfer.fetch(from: server.url, to: destination, maximumBytes: 1_000_000, allowsCellular: false, format: format)
        }

        #expect(!FileManager.default.fileExists(atPath: destination.path))
    }

    @Test func successfulHTTPContainingServerErrorIsNotAudio() async throws {
        let server = try await AudioServer.start(body: Data("{\"subsonic-response\":{\"status\":\"failed\"}}".utf8))
        defer { server.stop() }
        let destination = FileManager.default.temporaryDirectory.appending(path: "ServerError-\(UUID()).wav")
        defer { try? FileManager.default.removeItem(at: destination) }

        await #expect(throws: DownloadError.self) {
            try await DownloadTransfer.fetch(from: server.url, to: destination, maximumBytes: 1_000_000, allowsCellular: false, format: .original)
        }

        #expect(!FileManager.default.fileExists(atPath: destination.path))
    }

    @Test func oversizedResponseIsRejectedBeforeCommit() async throws {
        let server = try await AudioServer.start(body: waveAudio())
        defer { server.stop() }
        let destination = FileManager.default.temporaryDirectory.appending(path: "TooLarge-\(UUID()).wav")
        defer { try? FileManager.default.removeItem(at: destination) }

        await #expect(throws: DownloadError.self) {
            try await DownloadTransfer.fetch(from: server.url, to: destination, maximumBytes: 10, allowsCellular: false, format: .original)
        }

        #expect(!FileManager.default.fileExists(atPath: destination.path))
    }

    @Test func httpFailureIsReportedInsteadOfSavingResponse() async throws {
        let server = try await AudioServer.start(body: Data("Forbidden".utf8), status: 403)
        defer { server.stop() }
        let destination = FileManager.default.temporaryDirectory.appending(path: "Forbidden-\(UUID()).wav")
        defer { try? FileManager.default.removeItem(at: destination) }

        do {
            try await DownloadTransfer.fetch(from: server.url, to: destination, maximumBytes: 1_000_000, allowsCellular: false, format: .original)
            Issue.record("Expected an HTTP error")
        } catch DownloadError.http(let status) {
            #expect(status == 403)
        }

        #expect(!FileManager.default.fileExists(atPath: destination.path))
    }

    private func waveAudio() -> Data {
        let sampleRate: UInt32 = 8_000
        let sampleCount: UInt32 = 800
        let audioSize = sampleCount * 2
        var data = Data("RIFF".utf8)
        appendLittleEndian(audioSize + 36, to: &data)
        data.append(Data("WAVEfmt ".utf8))
        appendLittleEndian(UInt32(16), to: &data)
        appendLittleEndian(UInt16(1), to: &data)
        appendLittleEndian(UInt16(1), to: &data)
        appendLittleEndian(sampleRate, to: &data)
        appendLittleEndian(sampleRate * 2, to: &data)
        appendLittleEndian(UInt16(2), to: &data)
        appendLittleEndian(UInt16(16), to: &data)
        data.append(Data("data".utf8))
        appendLittleEndian(audioSize, to: &data)
        data.append(Data(repeating: 0, count: Int(audioSize)))
        return data
    }

    private func appendLittleEndian<Value: FixedWidthInteger>(_ value: Value, to data: inout Data) {
        withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
    }
}

private final class AudioServer: Sendable {
    private let listener: NWListener

    var url: URL { URL(string: "http://127.0.0.1:\(listener.port!.rawValue)/audio")! }

    private init(listener: NWListener) {
        self.listener = listener
    }

    static func start(body: Data, status: Int = 200) async throws -> AudioServer {
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: .any)
        let listener = try NWListener(using: parameters)
        let response = Data("HTTP/1.1 \(status) Response\r\nContent-Type: audio/wav\r\nContent-Length: \(body.count)\r\nConnection: close\r\n\r\n".utf8) + body
        listener.newConnectionHandler = { connection in
            connection.start(queue: .global())
            connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { _, _, _, _ in
                connection.send(content: response, completion: .contentProcessed { _ in connection.cancel() })
            }
        }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            listener.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    listener.stateUpdateHandler = nil
                    continuation.resume()
                case .failed(let error):
                    listener.stateUpdateHandler = nil
                    continuation.resume(throwing: error)
                default:
                    break
                }
            }
            listener.start(queue: .global())
        }
        return AudioServer(listener: listener)
    }

    func stop() { listener.cancel() }
}
