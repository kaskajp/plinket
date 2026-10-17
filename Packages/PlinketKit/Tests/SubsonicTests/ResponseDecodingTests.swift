import Foundation
import Testing
@testable import Subsonic

struct ResponseDecodingTests {
    @Test func albumList_decodesAlbums() async throws {
        let client = try makeStubbedClient(fixture: "getAlbumList2")

        let albums = try await client.albumList(.newest)

        #expect(albums.map(\.name) == [
            "netBloc Vol. 42: Live, The Universe & Everything",
            "netBloc Vol. 24: tiuqottigeloot",
        ])
    }

    @Test func albumList_decodesNanosecondDates() async throws {
        let client = try makeStubbedClient(fixture: "getAlbumList2")

        let albums = try await client.albumList(.newest)

        let created = try #require(albums.first?.created)
        #expect(created.timeIntervalSince1970.rounded(.down) == 1_743_028_009)
    }

    @Test func albumList_returnsEmptyWhenServerOmitsAlbumKey() async throws {
        let client = try makeStubbedClient(fixture: "emptyAlbumList2")

        let albums = try await client.albumList(.newest)

        #expect(albums.isEmpty)
    }

    @Test func album_decodesTracks() async throws {
        let client = try makeStubbedClient(fixture: "getAlbum")

        let detail = try await client.album(id: "5mCHAKT6FQSLoJKREdMum8")

        #expect(detail.songs.map { [$0.track, $0.duration] } == [[1, 211], [2, 168]])
    }

    @Test func album_decodesAlbumFieldsAlongsideTracks() async throws {
        let client = try makeStubbedClient(fixture: "getAlbum")

        let detail = try await client.album(id: "5mCHAKT6FQSLoJKREdMum8")

        #expect([detail.album.name, detail.album.artist] == ["Brighten", "Back On Earth"])
    }

    @Test func artists_flattensIndexes() async throws {
        let client = try makeStubbedClient(fixture: "getArtists")

        let artists = try await client.artists()

        #expect(artists.map(\.name) == ["2 Mello", "Back On Earth", "Binaerpilot"])
    }

    @Test func failedStatus_throwsServerError() async throws {
        let client = try makeStubbedClient(fixture: "error")

        await #expect(throws: SubsonicError.server(code: 40, message: "Wrong username or password")) {
            try await client.ping()
        }
    }

    @Test func nonSuccessHTTPStatus_throwsHTTPError() async throws {
        let client = makeStubbedClient { _ in StubURLProtocol.StubResponse(statusCode: 502) }

        await #expect(throws: SubsonicError.http(statusCode: 502)) {
            try await client.ping()
        }
    }

    @Test func nonJSONBody_throwsDecodingError() async throws {
        let client = makeStubbedClient { _ in StubURLProtocol.StubResponse(body: Data("<html>".utf8)) }

        await #expect {
            try await client.ping()
        } throws: { error in
            guard case SubsonicError.decoding = error else { return false }
            return true
        }
    }

    @Test func allAlbums_pagesUntilShortPage() async throws {
        let pageSize = SubsonicClient.maximumAlbumListPageSize
        let client = makeStubbedClient { request in
            let offset = request.url.flatMap { Int(queryItems(of: $0)["offset"] ?? "") } ?? 0
            let count = offset == 0 ? pageSize : 3
            return StubURLProtocol.StubResponse(body: albumListBody(ids: (offset..<offset + count).map(String.init)))
        }

        let albums = try await client.allAlbums()

        #expect(albums.count == pageSize + 3)
    }
}

private func albumListBody(ids: [String]) -> Data {
    let albums = ids.map { #"{"id":"\#($0)","name":"Album \#($0)"}"# }.joined(separator: ",")
    return Data(#"{"subsonic-response":{"status":"ok","version":"1.16.1","albumList2":{"album":[\#(albums)]}}}"#.utf8)
}
