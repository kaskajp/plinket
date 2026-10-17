import Foundation

/// Talks to a Subsonic-compatible server (e.g. Navidrome) using token authentication.
public actor SubsonicClient {
    public static let apiVersion = "1.16.1"
    public static let clientName = "plinket"
    public static let defaultSession = URLSession(configuration: .subsonicDefault)

    public nonisolated let config: ServerConfig
    private nonisolated let password: String
    private let session: URLSession

    public init(config: ServerConfig, password: String, session: URLSession = SubsonicClient.defaultSession) {
        self.config = config
        self.password = password
        self.session = session
    }

    /// Builds an authenticated URL; a fresh salt is drawn on every call.
    nonisolated func url(for endpoint: Endpoint, query: [URLQueryItem] = []) -> URL {
        let salt = TokenAuthentication.makeSalt()
        let authentication = [
            URLQueryItem(name: QueryName.username, value: config.username),
            URLQueryItem(name: QueryName.token, value: TokenAuthentication.token(password: password, salt: salt)),
            URLQueryItem(name: QueryName.salt, value: salt),
            URLQueryItem(name: QueryName.version, value: Self.apiVersion),
            URLQueryItem(name: QueryName.client, value: Self.clientName),
            URLQueryItem(name: QueryName.format, value: QueryValue.json),
        ]
        let endpointURL = config.baseURL.appending(path: Endpoint.pathPrefix).appending(path: endpoint.rawValue)
        // URLComponents leaves "+" unescaped, which servers decode as a space.
        let encodedQuery = (authentication + query)
            .map { "\(Self.percentEncoded($0.name))=\(Self.percentEncoded($0.value ?? ""))" }
            .joined(separator: "&")
        return URL(string: "\(endpointURL.absoluteString)?\(encodedQuery)") ?? endpointURL
    }

    func payload<Payload: SubsonicPayload>(
        _ endpoint: Endpoint,
        query: [URLQueryItem] = []
    ) async throws(SubsonicError) -> Payload {
        let envelope: ResponseEnvelope<Payload> = try await envelope(endpoint, query: query)
        guard let payload = envelope.payload else {
            throw .decoding("Missing \(Payload.responseKey ?? endpoint.rawValue) in response")
        }
        return payload
    }

    func perform(_ endpoint: Endpoint, query: [URLQueryItem] = []) async throws(SubsonicError) {
        let _: ResponseEnvelope<EmptyPayload> = try await envelope(endpoint, query: query)
    }

    private func envelope<Payload: SubsonicPayload>(
        _ endpoint: Endpoint,
        query: [URLQueryItem]
    ) async throws(SubsonicError) -> ResponseEnvelope<Payload> {
        let data = try await responseData(from: url(for: endpoint, query: query))
        let envelope = try Self.decodeEnvelope(Payload.self, from: data)
        guard envelope.status == .ok else {
            throw .server(code: envelope.error?.code ?? 0, message: envelope.error?.message ?? "Unknown server error")
        }
        return envelope
    }

    private func responseData(from url: URL) async throws(SubsonicError) -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(from: url)
        } catch let urlError as URLError {
            throw .transport(urlError)
        } catch is CancellationError {
            throw .transport(URLError(.cancelled))
        } catch {
            throw .transport(URLError(.unknown))
        }
        if let httpResponse = response as? HTTPURLResponse, !Self.successStatusCodes.contains(httpResponse.statusCode) {
            throw .http(statusCode: httpResponse.statusCode)
        }
        return data
    }

    private static let successStatusCodes = 200..<300

    private static func decodeEnvelope<Payload: SubsonicPayload>(
        _ payloadType: Payload.Type,
        from data: Data
    ) throws(SubsonicError) -> ResponseEnvelope<Payload> {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .subsonic
        do {
            return try decoder.decode(ResponseEnvelope<Payload>.self, from: data)
        } catch {
            throw .decoding(String(describing: error))
        }
    }

    private static let queryValueAllowedCharacters = CharacterSet.urlQueryAllowed.subtracting(CharacterSet(charactersIn: "+&=?#"))

    private static func percentEncoded(_ text: String) -> String {
        text.addingPercentEncoding(withAllowedCharacters: queryValueAllowedCharacters) ?? text
    }
}

extension URLSessionConfiguration {
    static var subsonicDefault: URLSessionConfiguration {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 15
        return configuration
    }
}

enum Endpoint: String {
    static let pathPrefix = "rest"

    case ping
    case getAlbumList2
    case getAlbum
    case getArtists
    case getArtist
    case search3
    case getPlaylists
    case getPlaylist
    case getStarred2
    case star
    case unstar
    case scrobble
    case stream
    case getCoverArt
}

enum QueryName {
    static let username = "u"
    static let token = "t"
    static let salt = "s"
    static let version = "v"
    static let client = "c"
    static let format = "f"
    static let id = "id"
    static let albumID = "albumId"
    static let artistID = "artistId"
    static let type = "type"
    static let size = "size"
    static let offset = "offset"
    static let fromYear = "fromYear"
    static let toYear = "toYear"
    static let query = "query"
    static let artistCount = "artistCount"
    static let albumCount = "albumCount"
    static let songCount = "songCount"
    static let time = "time"
    static let submission = "submission"
    static let streamFormat = "format"
}

enum QueryValue {
    static let json = "json"
    static let rawStream = "raw"
}
