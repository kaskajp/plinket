import Foundation

/// A failure talking to a Subsonic server.
public enum SubsonicError: Error, Sendable, Equatable {
    /// The server answered with `status: failed`; codes follow the Subsonic spec (e.g. 40 = wrong credentials).
    case server(code: Int, message: String)
    case http(statusCode: Int)
    case decoding(String)
    case transport(URLError)
}

extension SubsonicError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .server(_, let message):
            message
        case .http(let statusCode):
            "The server responded with HTTP \(statusCode)."
        case .decoding:
            "The server sent a response Plinket could not read."
        case .transport(let urlError):
            urlError.localizedDescription
        }
    }
}
