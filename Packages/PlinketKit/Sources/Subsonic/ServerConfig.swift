import Foundation

/// The server and account a `SubsonicClient` talks to.
public struct ServerConfig: Codable, Sendable, Hashable {
    public let baseURL: URL
    public let username: String

    public init(baseURL: URL, username: String) {
        self.baseURL = baseURL
        self.username = username
    }

    /// Builds a config from a user-typed address. Only HTTPS is accepted, and assumed when no scheme is given.
    public init?(serverAddress: String, username: String) {
        guard let baseURL = Self.normalizedBaseURL(from: serverAddress) else { return nil }
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedUsername.isEmpty else { return nil }
        self.init(baseURL: baseURL, username: trimmedUsername)
    }

    private static let scheme = "https"

    private static func normalizedBaseURL(from serverAddress: String) -> URL? {
        var address = serverAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        if !address.contains("://") {
            address = "\(scheme)://\(address)"
        }
        guard var components = URLComponents(string: address),
              components.scheme?.lowercased() == scheme,
              let host = components.host, !host.isEmpty
        else { return nil }
        components.scheme = scheme
        while components.path.hasSuffix("/") {
            components.path.removeLast()
        }
        return components.url
    }
}
