import Foundation
import Testing
@testable import Subsonic

enum Fixture {
    static func data(named name: String) throws -> Data {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
        return try Data(contentsOf: url)
    }
}

let testPassword = "sesame"

func makeConfig(host: String = uniqueHost(), path: String = "") -> ServerConfig {
    ServerConfig(baseURL: URL(string: "https://\(host)\(path)")!, username: "demo")
}

func uniqueHost() -> String {
    "\(UUID().uuidString.lowercased()).test"
}

/// A client whose requests are answered by `handler` instead of the network.
func makeStubbedClient(handler: @escaping StubURLProtocol.Handler) -> SubsonicClient {
    let config = makeConfig()
    let session = StubURLProtocol.session(forHost: config.baseURL.host() ?? "", handler: handler)
    return SubsonicClient(config: config, password: testPassword, session: session)
}

func makeStubbedClient(fixture name: String, statusCode: Int = 200) throws -> SubsonicClient {
    let body = try Fixture.data(named: name)
    return makeStubbedClient { _ in StubURLProtocol.StubResponse(statusCode: statusCode, body: body) }
}

func queryItems(of url: URL) -> [String: String] {
    let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
    return Dictionary(items.map { ($0.name, $0.value ?? "") }, uniquingKeysWith: { first, _ in first })
}
