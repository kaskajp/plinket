import CoreGraphics
import Foundation
import ImageIO
import Library
import Subsonic
import UniformTypeIdentifiers

func uniqueHost() -> String {
    "\(UUID().uuidString.lowercased()).test"
}

func makeStubbedClient(handler: @escaping StubURLProtocol.Handler) -> SubsonicClient {
    makeStubbedServer(handler: handler).client
}

/// An image cache whose cover art downloads are answered by `handler`.
func makeStubbedImageCache(directory: URL, handler: @escaping StubURLProtocol.Handler) -> ImageCache {
    let server = makeStubbedServer(handler: handler)
    return ImageCache(client: server.client, directory: directory, session: server.session)
}

private func makeStubbedServer(handler: @escaping StubURLProtocol.Handler) -> (client: SubsonicClient, session: URLSession) {
    let host = uniqueHost()
    let config = ServerConfig(baseURL: URL(string: "https://\(host)")!, username: "demo")
    let session = StubURLProtocol.session(forHost: host, handler: handler)
    return (SubsonicClient(config: config, password: "sesame", session: session), session)
}

func makeTemporaryDirectory() -> URL {
    FileManager.default.temporaryDirectory.appending(path: "PlinketTests-\(UUID().uuidString)")
}

func makeIsolatedDefaults() -> UserDefaults {
    UserDefaults(suiteName: "PlinketTests-\(UUID().uuidString)")!
}

func albumListResponse(_ albums: [(id: String, name: String)]) -> StubURLProtocol.StubResponse {
    let albumJSON = albums.map { #"{"id":"\#($0.id)","name":"\#($0.name)"}"# }.joined(separator: ",")
    return subsonicResponse("albumList2", json: #"{"album":[\#(albumJSON)]}"#)
}

/// A successful response carrying `json` under `key`, or nothing beyond the status when `key` is `nil`.
func subsonicResponse(_ key: String? = nil, json: String = "{}") -> StubURLProtocol.StubResponse {
    let payload = key.map { #","\#($0)":\#(json)"# } ?? ""
    let body = #"{"subsonic-response":{"status":"ok","version":"1.16.1"\#(payload)}}"#
    return StubURLProtocol.StubResponse(body: Data(body.utf8))
}

/// Answers each endpoint, e.g. `getArtists`, from `responses` and everything else with HTTP 503.
func routedHandler(_ responses: [String: StubURLProtocol.StubResponse]) -> StubURLProtocol.Handler {
    { request in
        responses[request.url?.lastPathComponent ?? ""] ?? StubURLProtocol.StubResponse(statusCode: 503)
    }
}

func pngData(width: Int, height: Int) -> Data {
    let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    context.setFillColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    let data = NSMutableData()
    let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, context.makeImage()!, nil)
    CGImageDestinationFinalize(destination)
    return data as Data
}
