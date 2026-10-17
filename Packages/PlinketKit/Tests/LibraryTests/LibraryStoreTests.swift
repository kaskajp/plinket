import Foundation
import Library
import Subsonic
import Testing

@MainActor
struct LibraryStoreTests {
    private let cacheDirectory = makeTemporaryDirectory()
    private let defaults = makeIsolatedDefaults()

    @Test func refresh_persistsSnapshotForNextLaunch() async {
        let onlineClient = makeStubbedClient { _ in albumListResponse([("1", "Brighten")]) }
        await makeStore(client: onlineClient).refresh(.albums)
        let relaunchedStore = makeStore(client: makeOfflineClient())

        await relaunchedStore.loadCachedSnapshots()

        #expect(relaunchedStore.albums.map(\.name) == ["Brighten"])
    }

    @Test func refresh_keepsCachedAlbumsWhenServerFails() async {
        let onlineClient = makeStubbedClient { _ in albumListResponse([("1", "Brighten")]) }
        await makeStore(client: onlineClient).refresh(.albums)
        let offlineStore = makeStore(client: makeOfflineClient())
        await offlineStore.loadCachedSnapshots()

        await offlineStore.refresh(.albums)

        #expect(offlineStore.albums.map(\.name) == ["Brighten"] && offlineStore.refreshError(for: .albums) == .http(statusCode: 503))
    }

    @Test func albumSort_isRestoredOnNextLaunch() {
        let client = makeOfflineClient()
        makeStore(client: client).albumSort = .year

        let relaunchedStore = makeStore(client: client)

        #expect(relaunchedStore.albumSort == .year)
    }

    @Test func refreshArtists_persistsSnapshotForNextLaunch() async {
        let onlineClient = makeStubbedClient(handler: routedHandler(["getArtists": artistsResponse]))
        await makeStore(client: onlineClient).refresh(.artists)
        let relaunchedStore = makeStore(client: makeOfflineClient())

        await relaunchedStore.loadCachedSnapshots()

        #expect(relaunchedStore.artists.map(\.name) == ["Back On Earth"])
    }

    @Test func refreshPlaylists_persistsSnapshotForNextLaunch() async {
        let onlineClient = makeStubbedClient(handler: routedHandler(["getPlaylists": playlistsResponse]))
        await makeStore(client: onlineClient).refresh(.playlists)
        let relaunchedStore = makeStore(client: makeOfflineClient())

        await relaunchedStore.loadCachedSnapshots()

        #expect(relaunchedStore.playlists.map(\.name) == ["Morning"])
    }

    @Test func artistDetail_isFetchedOnceUntilNextRefresh() async throws {
        let recorder = RequestRecorder()
        let respond = routedHandler(["getArtist": artistResponse])
        let store = makeStore(client: makeStubbedClient { request in
            recorder.record(request)
            return respond(request)
        })

        try await store.artistDetail(id: "ar-1")
        try await store.artistDetail(id: "ar-1")

        #expect(recorder.urls.count == 1)
    }

    @Test func playlistDetail_isRefetchedAfterPlaylistsRefresh() async throws {
        let recorder = RequestRecorder()
        let respond = routedHandler(["getPlaylists": playlistsResponse, "getPlaylist": playlistResponse])
        let store = makeStore(client: makeStubbedClient { request in
            recorder.record(request)
            return respond(request)
        })
        try await store.playlistDetail(id: "pl-1")

        await store.refresh(.playlists)
        try await store.playlistDetail(id: "pl-1")

        #expect(recorder.urls.filter { $0.lastPathComponent == "getPlaylist" }.count == 2)
    }

    @Test func artistDetail_ordersAlbumsOldestFirst() async throws {
        let store = makeStore(client: makeStubbedClient(handler: routedHandler(["getArtist": artistResponse])))

        let detail = try await store.artistDetail(id: "ar-1")

        #expect(detail.albums.map(\.year) == [1999, 2004])
    }

    @Test func search_doesNotAskServerForBlankText() async throws {
        let recorder = RequestRecorder()
        let store = makeStore(client: makeStubbedClient { request in
            recorder.record(request)
            return subsonicResponse("searchResult3")
        })

        _ = try await store.search("  ")

        #expect(recorder.urls.isEmpty)
    }

    @Test func refreshStarred_decidesStarForCopiesHeldElsewhere() async {
        let store = makeStore(client: makeStubbedClient(handler: routedHandler(["getStarred2": starredResponse])))
        let queuedCopy = Song(id: "s-1", title: "Gold")

        await store.refresh(.starred)

        #expect(store.isStarred(queuedCopy))
    }

    @Test func setStarred_marksAlbumStarredBeforeServerAnswers() async {
        let (starRequests, starRequestContinuation) = AsyncStream<Void>.makeStream()
        let serverAnswer = DispatchSemaphore(value: 0)
        let store = makeStore(client: makeStubbedClient { request in
            guard request.url?.lastPathComponent == "star" else { return albumListResponse([("1", "Brighten")]) }
            starRequestContinuation.yield()
            serverAnswer.wait()
            return subsonicResponse()
        })
        await store.refresh(.albums)

        let starring = Task { await store.setStarred(true, album: store.albums[0]) }
        for await _ in starRequests { break }
        let isStarredWhilePending = store.albums[0].isStarred
        serverAnswer.signal()
        await starring.value

        #expect(isStarredWhilePending)
    }

    @Test func setStarred_rollsBackAlbumWhenServerFails() async {
        let store = makeStore(client: makeStubbedClient(handler: routedHandler([
            "getAlbumList2": albumListResponse([("1", "Brighten")]),
        ])))
        await store.refresh(.albums)

        await store.setStarred(true, album: store.albums[0])

        #expect(store.albums[0].isStarred == false)
    }

    @Test func setStarred_reportsErrorWhenServerFails() async {
        let store = makeStore(client: makeOfflineClient())

        await store.setStarred(true, song: Song(id: "s-1", title: "Gold"))

        #expect(store.starError == .http(statusCode: 503))
    }

    @Test func setStarred_marksSongStarredInCachedAlbumDetail() async throws {
        let store = makeStore(client: makeStubbedClient(handler: routedHandler([
            "getAlbum": albumResponse,
            "star": subsonicResponse(),
        ])))
        let detail = try await store.albumDetail(id: "al-1")

        await store.setStarred(true, song: detail.songs[0])

        #expect(store.cachedAlbumDetail(id: "al-1")?.songs[0].isStarred == true)
    }

    @Test func setStarred_marksCopiesHeldElsewhereStarredBeforeStarredLoads() async {
        let store = makeStore(client: makeStubbedClient(handler: routedHandler(["star": subsonicResponse()])))

        await store.setStarred(true, song: Song(id: "s-1", title: "Gold"))

        #expect(store.isStarred(Song(id: "s-1", title: "Gold")))
    }

    @Test func setStarred_removesUnstarredArtistFromStarred() async {
        let store = makeStore(client: makeStubbedClient(handler: routedHandler([
            "getStarred2": starredResponse,
            "unstar": subsonicResponse(),
        ])))
        await store.refresh(.starred)

        await store.setStarred(false, artist: store.starred.artists[0])

        #expect(store.starred.artists.isEmpty)
    }

    private func makeStore(client: SubsonicClient) -> LibraryStore {
        LibraryStore(client: client, cacheDirectory: cacheDirectory, defaults: defaults)
    }

    private func makeOfflineClient() -> SubsonicClient {
        makeStubbedClient { _ in StubURLProtocol.StubResponse(statusCode: 503) }
    }
}

private let artistsResponse = subsonicResponse(
    "artists",
    json: #"{"index":[{"name":"B","artist":[{"id":"ar-1","name":"Back On Earth"}]}]}"#
)

private let artistResponse = subsonicResponse(
    "artist",
    json: #"{"id":"ar-1","name":"Back On Earth","album":[{"id":"al-2","name":"Later","year":2004},{"id":"al-1","name":"Debut","year":1999}]}"#
)

private let playlistsResponse = subsonicResponse("playlists", json: #"{"playlist":[{"id":"pl-1","name":"Morning"}]}"#)

private let playlistResponse = subsonicResponse(
    "playlist",
    json: #"{"id":"pl-1","name":"Morning","entry":[{"id":"s-1","title":"Gold"}]}"#
)

private let albumResponse = subsonicResponse(
    "album",
    json: #"{"id":"al-1","name":"Debut","song":[{"id":"s-1","title":"Gold"}]}"#
)

private let starredResponse = subsonicResponse(
    "starred2",
    json: #"""
    {"song":[{"id":"s-1","title":"Gold","starred":"2026-10-15T00:00:00Z"}],
     "artist":[{"id":"ar-1","name":"Back On Earth","starred":"2026-10-15T00:00:00Z"}]}
    """#
)
