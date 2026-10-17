import Foundation
import Synchronization

/// Serves canned responses keyed by host, so parallel tests each own a host and never share a handler.
final class StubURLProtocol: URLProtocol {
    struct StubResponse: Sendable {
        var statusCode = 200
        var body = Data()
    }

    typealias Handler = @Sendable (URLRequest) -> StubResponse

    private static let handlers = Mutex<[String: Handler]>([:])

    static func session(forHost host: String, handler: @escaping Handler) -> URLSession {
        handlers.withLock { $0[host] = handler }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url,
              let host = url.host(),
              let handler = Self.handlers.withLock({ $0[host] })
        else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }
        let stub = handler(request)
        let response = HTTPURLResponse(url: url, statusCode: stub.statusCode, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: stub.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

/// Collects the URLs a stubbed session was asked for.
final class RequestRecorder: Sendable {
    private let recordedURLs = Mutex<[URL]>([])

    var urls: [URL] { recordedURLs.withLock { $0 } }

    func record(_ request: URLRequest) {
        guard let url = request.url else { return }
        recordedURLs.withLock { $0.append(url) }
    }
}
