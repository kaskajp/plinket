import AVFoundation
import Foundation
import Network
import Playback
import Testing

@MainActor
struct QueuePlayerEngineTests {
    // AVFoundation must decode and start real audio; the response is released by the waiting event, not a timer.
    @Test(.timeLimit(.minutes(1)))
    func delayedAudioReportsWaitingThenClearsWhenPlaybackStarts() async throws {
        let directory = makeTemporaryDirectory()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "silence.wav")
        let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 8_000, channels: 1))
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 8_000))
        buffer.frameLength = 8_000
        buffer.floatChannelData?[0].initialize(repeating: 0, count: 8_000)
        do {
            let file = try AVAudioFile(forWriting: url, settings: [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: 8_000,
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false,
            ])
            try file.write(from: buffer)
        }
        let server = try await GatedAudioServer.start(body: Data(contentsOf: url))
        defer { server.stop() }
        let engine = QueuePlayerEngine()
        let player = PlayerController(engine: engine, streamURL: { _ in server.url })
        defer { player.shutDown() }
        var observedWaiting = false
        var observedPlaying = false
        let handleEvent = engine.onEvent

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            engine.onEvent = { event in
                handleEvent?(event)
                switch event {
                case .bufferingChanged(_, true):
                    observedWaiting = observedWaiting || player.isBuffering
                    server.releaseAudio()
                case .progressed(let position, _):
                    if position > 0, player.isPlaying, !player.isBuffering {
                        observedPlaying = observedWaiting
                    }
                case .reachedEnd:
                    engine.onEvent = nil
                    continuation.resume()
                case .failed(_, let message):
                    engine.onEvent = nil
                    continuation.resume(throwing: NSError(domain: "PlaybackTest", code: 1, userInfo: [NSLocalizedDescriptionKey: message]))
                default:
                    break
                }
            }
            player.play(songs: [makeSong("delayed")])
        }

        #expect(observedWaiting && observedPlaying)
        #expect(!player.isPlaying && !player.isBuffering)
    }
}

@MainActor
private final class GatedAudioServer {
    private struct Request {
        let connection: NWConnection
        let data: Data
    }

    private let listener: NWListener
    private let body: Data
    private var pending: [Request] = []
    private var connections: [NWConnection] = []
    private var isReleased = false

    var url: URL { URL(string: "http://127.0.0.1:\(listener.port!.rawValue)/audio.wav")! }

    private init(listener: NWListener, body: Data) {
        self.listener = listener
        self.body = body
        listener.newConnectionHandler = { [weak self] connection in
            MainActor.assumeIsolated {
                self?.connections.append(connection)
                connection.start(queue: .main)
                connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, _, _ in
                    guard let data else { return }
                    MainActor.assumeIsolated { self?.handleRequest(Request(connection: connection, data: data)) }
                }
            }
        }
    }

    static func start(body: Data) async throws -> GatedAudioServer {
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: .any)
        let listener = try NWListener(using: parameters)
        let server = GatedAudioServer(listener: listener, body: body)
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
            listener.start(queue: .main)
        }
        return server
    }

    func releaseAudio() {
        isReleased = true
        for request in pending {
            sendAudio(to: request)
        }
        pending.removeAll()
    }

    func stop() {
        listener.cancel()
        for connection in connections {
            connection.cancel()
        }
    }

    private func handleRequest(_ request: Request) {
        guard isReleased else {
            pending.append(request)
            return
        }
        sendAudio(to: request)
    }

    private func sendAudio(to request: Request) {
        let rangeHeader = String(decoding: request.data, as: UTF8.self).components(separatedBy: "\r\n")
            .first { $0.lowercased().hasPrefix("range: bytes=") }
        let bounds = rangeHeader?.dropFirst("Range: bytes=".count).split(separator: "-", omittingEmptySubsequences: false)
        let start = bounds?.first.flatMap { Int($0) } ?? 0
        let end = min(bounds?.last.flatMap { Int($0) } ?? body.count - 1, body.count - 1)
        let audio = body[start...end]
        let status = rangeHeader == nil ? "200 OK" : "206 Partial Content"
        let contentRange = rangeHeader == nil ? "" : "Content-Range: bytes \(start)-\(end)/\(body.count)\r\n"
        let response = Data("HTTP/1.1 \(status)\r\nContent-Type: audio/wav\r\nContent-Length: \(audio.count)\r\nAccept-Ranges: bytes\r\n\(contentRange)Connection: close\r\n\r\n".utf8) + audio
        request.connection.send(content: response, completion: .contentProcessed { _ in request.connection.cancel() })
    }
}
