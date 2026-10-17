import Foundation

/// The server and account a `SubsonicClient` talks to.
public struct ServerConfig: Codable, Sendable, Hashable {
    public let baseURL: URL
    public let username: String

    public init(baseURL: URL, username: String) {
        self.baseURL = baseURL
        self.username = username
    }

    /// Builds a config from a user-typed address, assuming HTTPS when no scheme is given.
    public init?(serverAddress: String, username: String) {
        guard let baseURL = Self.normalizedBaseURL(from: serverAddress) else { return nil }
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedUsername.isEmpty else { return nil }
        self.init(baseURL: baseURL, username: trimmedUsername)
    }

    private static let supportedSchemes: Set<String> = ["http", "https"]
    private static let defaultScheme = "https"

    private static func normalizedBaseURL(from serverAddress: String) -> URL? {
        var address = serverAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        if !address.contains("://") {
            address = "\(defaultScheme)://\(address)"
        }
        guard var components = URLComponents(string: address),
              let scheme = components.scheme?.lowercased(),
              supportedSchemes.contains(scheme),
              let host = components.host, !host.isEmpty
        else { return nil }
        while components.path.hasSuffix("/") {
            components.path.removeLast()
        }
        return components.url
    }
}
