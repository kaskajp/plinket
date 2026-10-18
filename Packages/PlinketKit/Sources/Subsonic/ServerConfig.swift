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
    /// Plain HTTP is accepted only for servers on the local network.
    public init(serverAddress: String, username: String) throws(ServerAddressError) {
        let baseURL = try Self.normalizedBaseURL(from: serverAddress)
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedUsername.isEmpty else { throw .invalid }
        self.init(baseURL: baseURL, username: trimmedUsername)
    }

    private static let defaultScheme = "https"

    private static func normalizedBaseURL(from serverAddress: String) throws(ServerAddressError) -> URL {
        var address = serverAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        if !address.contains("://") {
            address = "\(defaultScheme)://\(address)"
        }
        guard var components = URLComponents(string: address),
              let scheme = components.scheme?.lowercased(),
              let host = components.host, !host.isEmpty
        else { throw .invalid }
        switch scheme {
        case "https":
            break
        case "http":
            guard LocalNetworkHost.contains(host) else { throw .plainHTTPOutsideLocalNetwork }
        default:
            throw .invalid
        }
        components.scheme = scheme
        while components.path.hasSuffix("/") {
            components.path.removeLast()
        }
        guard let url = components.url else { throw .invalid }
        return url
    }
}

/// Why a typed server address can't be used.
public enum ServerAddressError: Error, Sendable, Equatable {
    case invalid
    case plainHTTPOutsideLocalNetwork
}
