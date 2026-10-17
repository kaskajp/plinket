import Foundation
import Testing
@testable import Subsonic

struct URLCompositionTests {
    @Test func url_includesProtocolParameters() {
        let client = SubsonicClient(config: makeConfig(), password: testPassword)

        let query = queryItems(of: client.streamURL(songID: "song-1"))

        #expect(query.filter { ["u", "v", "c", "f"].contains($0.key) } == [
            "u": "demo",
            "v": "1.16.1",
            "c": "plinket",
            "f": "json",
        ])
    }

    @Test func streamURL_requestsUntranscodedFile() {
        let client = SubsonicClient(config: makeConfig(), password: testPassword)

        let query = queryItems(of: client.streamURL(songID: "song-1"))

        #expect(query["id"] == "song-1" && query["format"] == "raw")
    }

    @Test func url_keepsServerSubpath() {
        let client = SubsonicClient(config: makeConfig(path: "/music"), password: testPassword)

        let url = client.coverArtURL(id: "al-1", size: 300)

        #expect(url.path() == "/music/rest/getCoverArt")
    }

    @Test func search_percentEncodesReservedCharactersInQuery() async throws {
        let recorder = RequestRecorder()
        let body = try Fixture.data(named: "emptyAlbumList2")
        let client = makeStubbedClient { request in
            recorder.record(request)
            return StubURLProtocol.StubResponse(body: body)
        }

        _ = try? await client.search("AC+DC & friends")

        let encodedQuery = try #require(recorder.urls.first?.query(percentEncoded: true))
        #expect(encodedQuery.contains("query=AC%2BDC%20%26%20friends"))
    }

    @Test func star_sendsAlbumIDParameter() async throws {
        let recorder = RequestRecorder()
        let body = try Fixture.data(named: "emptyAlbumList2")
        let client = makeStubbedClient { request in
            recorder.record(request)
            return StubURLProtocol.StubResponse(body: body)
        }

        try await client.star(.album("al-1"))

        let url = try #require(recorder.urls.first)
        #expect(queryItems(of: url)["albumId"] == "al-1")
    }
}
