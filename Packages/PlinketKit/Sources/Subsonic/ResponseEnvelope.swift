import Foundation

/// A value found under its own key inside the `subsonic-response` envelope.
protocol SubsonicPayload: Decodable {
    /// `nil` for responses that carry nothing beyond the status, e.g. `ping`.
    static var responseKey: String? { get }
}

/// Decodes `{"subsonic-response": {"status": …, "error": …, "<responseKey>": …}}`.
struct ResponseEnvelope<Payload: SubsonicPayload>: Decodable {
    enum Status: String, Decodable {
        case ok
        case failed
    }

    struct ServerError: Decodable {
        let code: Int
        let message: String?
    }

    let status: Status
    let error: ServerError?
    let payload: Payload?

    init(from decoder: any Decoder) throws {
        let root = try decoder.container(keyedBy: ResponseKey.self)
        let body = try root.nestedContainer(keyedBy: ResponseKey.self, forKey: .envelope)
        status = try body.decode(Status.self, forKey: .status)
        error = try body.decodeIfPresent(ServerError.self, forKey: .error)
        guard let responseKey = Payload.responseKey else {
            payload = nil
            return
        }
        payload = try body.decodeIfPresent(Payload.self, forKey: ResponseKey(stringValue: responseKey))
    }
}

struct EmptyPayload: SubsonicPayload {
    static let responseKey: String? = nil
}

struct AlbumListPayload: SubsonicPayload {
    static let responseKey: String? = "albumList2"
    let album: [Album]?
}

struct ArtistIndexesPayload: SubsonicPayload {
    struct Index: Decodable {
        let artist: [Artist]?
    }

    static let responseKey: String? = "artists"
    let index: [Index]?
}

struct PlaylistsPayload: SubsonicPayload {
    static let responseKey: String? = "playlists"
    let playlist: [Playlist]?
}

extension AlbumDetail: SubsonicPayload {
    static let responseKey: String? = "album"
}

extension ArtistDetail: SubsonicPayload {
    static let responseKey: String? = "artist"
}

extension PlaylistDetail: SubsonicPayload {
    static let responseKey: String? = "playlist"
}

extension SearchResult: SubsonicPayload {
    static let responseKey: String? = "searchResult3"
}

extension Starred: SubsonicPayload {
    static let responseKey: String? = "starred2"
}

struct ResponseKey: CodingKey {
    static let envelope = ResponseKey(stringValue: "subsonic-response")
    static let status = ResponseKey(stringValue: "status")
    static let error = ResponseKey(stringValue: "error")

    let stringValue: String
    let intValue: Int? = nil

    init(stringValue: String) {
        self.stringValue = stringValue
    }

    init?(intValue: Int) {
        nil
    }
}

extension JSONDecoder.DateDecodingStrategy {
    /// ISO 8601 with or without fractional seconds; Navidrome sends up to nanosecond precision.
    static let subsonic = custom { decoder in
        let container = try decoder.singleValueContainer()
        let text = try container.decode(String.self)
        if let date = try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(text) {
            return date
        }
        if let date = try? Date.ISO8601FormatStyle().parse(text) {
            return date
        }
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unrecognized date \(text)")
    }
}
