import Foundation
import Synchronization
import Testing
@testable import Feedback

private func report(title: String = "Playback stops", details: String = "After the first song", screenshots: [Data] = []) -> ProblemReport {
    ProblemReport(id: UUID(), title: title, details: details, appVersion: "1.1.0 (2)",
                  platform: "iOS", osVersion: "27.2", locale: "en-US", screenshots: screenshots)
}

@Test func validatesDraftBeforeSubmission() {
    #expect(!report(title: " \n").isValid)
    #expect(!report(details: "").isValid)
    #expect(!report(title: String(repeating: "x", count: 201)).isValid)
    #expect(!report(details: String(repeating: "x", count: 10_001)).isValid)
    #expect(!report(screenshots: Array(repeating: Data([1]), count: 4)).isValid)
    #expect(!report(screenshots: [Data(count: ProblemReport.maximumScreenshotBytes + 1)]).isValid)
    #expect(report(title: " Summary ", details: " Details ").isValid)
    #expect(report(title: " Summary ").title == "Summary")
}

@Test func sendsReportAndScreenshotWithoutCredentials() async throws {
    let draft = report(screenshots: [Data([0xff, 0xd8, 0xff, 0xd9])])
    let recorder = Mutex<URLRequest?>(nil)
    let session = FeedbackURLProtocol.session { request in
        recorder.withLock { $0 = request }
        return .init(status: 201, data: Data("{\"id\":\"\(draft.id)\"}".utf8))
    }
    try await FeedbackClient(endpoint: URL(string: "https://relay.example/report")!, session: session).submit(draft)
    let request = try #require(recorder.withLock { $0 })
    #expect(request.httpMethod == "POST")
    #expect(request.url?.path == "/report")
    #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
    #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
    let payload = try JSONDecoder().decode(ProblemReport.self, from: requestBody(request))
    #expect(payload.id == draft.id)
    #expect(payload.title == draft.title)
    #expect(payload.details == draft.details)
    #expect(payload.screenshots == draft.screenshots)
    #expect(payload.appVersion == draft.appVersion)
}

@Test func requiresReceiptForTheSubmittedReport() async {
    let draft = report()
    for response in [
        FeedbackURLProtocol.Response(status: 200, data: Data()),
        .init(status: 201, data: Data("{}".utf8)),
        .init(status: 201, data: Data("{\"id\":\"\(UUID())\"}".utf8)),
        .init(status: 502, data: Data()),
        .init(status: 429, data: Data()),
    ] {
        let session = FeedbackURLProtocol.session { _ in response }
        await #expect(throws: (any Error).self) {
            try await FeedbackClient(endpoint: URL(string: "https://relay.example/report")!, session: session).submit(draft)
        }
    }
}

@Test func refusesInvalidReportsAndInsecureEndpointsWithoutSending() async {
    let requests = Mutex(0)
    let session = FeedbackURLProtocol.session { _ in
        requests.withLock { $0 += 1 }
        return .init(status: 201, data: Data())
    }
    await #expect(throws: (any Error).self) {
        try await FeedbackClient(endpoint: URL(string: "https://relay.example/report")!, session: session).submit(report(title: ""))
    }
    await #expect(throws: (any Error).self) {
        try await FeedbackClient(endpoint: URL(string: "http://relay.example/report")!, session: session).submit(report())
    }
    #expect(requests.withLock { $0 } == 0)
}

private func requestBody(_ request: URLRequest) throws -> Data {
    if let data = request.httpBody { return data }
    let stream = try #require(request.httpBodyStream)
    stream.open()
    defer { stream.close() }
    var data = Data()
    var buffer = [UInt8](repeating: 0, count: 4096)
    while stream.hasBytesAvailable {
        let count = stream.read(&buffer, maxLength: buffer.count)
        guard count >= 0 else { throw stream.streamError ?? URLError(.cannotDecodeContentData) }
        if count == 0 { break }
        data.append(contentsOf: buffer.prefix(count))
    }
    return data
}

private final class FeedbackURLProtocol: URLProtocol {
    struct Response: Sendable {
        let status: Int
        let data: Data
    }
    private typealias Handler = @Sendable (URLRequest) -> Response
    private static let handlers = Mutex<[String: Handler]>([:])

    static func session(handler: @escaping @Sendable (URLRequest) -> Response) -> URLSession {
        let key = UUID().uuidString
        handlers.withLock { $0[key] = handler }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [FeedbackURLProtocol.self]
        configuration.httpAdditionalHeaders = ["X-Test-ID": key]
        return URLSession(configuration: configuration)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let key = request.value(forHTTPHeaderField: "X-Test-ID") ?? ""
        guard let handler = Self.handlers.withLock({ $0[key] }), let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        let result = handler(request)
        let response = HTTPURLResponse(url: url, statusCode: result.status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: result.data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
