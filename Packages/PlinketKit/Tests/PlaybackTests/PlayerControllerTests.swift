import Foundation
@testable import Playback
import Subsonic
import Testing

@MainActor
struct PlayerControllerTests {
    private let engine = FakeEngine()
    private let songs = [makeSong("a"), makeSong("b"), makeSong("c")]

    @Test func downloadedSongsUseLocalFilesForCurrentAndPreloadedItems() {
        let local = URL(filePath: "/offline/song.mp3")
        let remote = URL(string: "https://music.example/stream")!
        let player = PlayerController(
            engine: engine, streamURL: { _ in remote },
            localURL: { $0.id == "c" ? nil : local }
        )
        let sourceSongs = [Song(id: "a", title: "Original", contentType: "audio/flac"), makeSong("b"), makeSong("c")]
        player.play(songs: sourceSongs)

        #expect(engine.loadedItem?.url == local)
        #expect(engine.preloadedItem?.url == local)
        #expect(engine.loadedItem?.contentType == nil)

        player.next()

        #expect(engine.preloadedItem?.url == remote)
    }

    @Test func restoredQueueUsesDownloadedFilesWithoutStreaming() async {
        let directory = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = QueueStore(directory: directory)
        let original = PlayerController(engine: FakeEngine(), streamURL: { _ in URL(filePath: "/old") }, queueStore: store)
        original.play(songs: songs)
        await original.saveQueue()
        let local = URL(filePath: "/offline/song.mp3")
        let restored = PlayerController(
            engine: engine, streamURL: { _ in Issue.record("Downloaded queue must not stream"); return URL(filePath: "/unexpected") },
            localURL: { _ in local }, queueStore: store
        )

        await restored.restoreSavedQueue()

        #expect(restored.currentSong?.id == "a")
        #expect(engine.loadedItem?.url == local)
        #expect(!restored.isPlaying)
    }

    @Test func naturalAdvance_movesQueueWithoutReloading() {
        let player = makePlayer()
        player.play(songs: songs)

        engine.finishCurrentItem()

        #expect(player.currentSong?.id == "b" && engine.loadCount == 1)
    }

    @Test func naturalAdvance_preloadsTheFollowingEntry() {
        let player = makePlayer()
        player.play(songs: songs)

        engine.finishCurrentItem()

        #expect(engine.preloadedItem?.id == player.entries[2].id)
    }

    @Test func naturalAdvance_withRepeatOneReplaysSameEntry() {
        let player = makePlayer()
        player.play(songs: songs)
        player.setRepeat(.one)

        engine.finishCurrentItem()

        #expect(player.currentIndex == 0 && engine.preloadedItem?.id == player.entries[0].id)
    }

    @Test func endOfQueue_withRepeatOffStopsOnLastSongRewound() {
        let player = makePlayer()
        player.play(songs: songs, startingAt: 2)
        engine.emit(.progressed(position: 199, duration: 200))

        engine.finishCurrentItem()

        #expect(!player.isPlaying && player.currentSong?.id == "c" && player.position == 0)
    }

    @Test func setRepeatAll_onLastSongPreloadsFirst() {
        let player = makePlayer()
        player.play(songs: songs, startingAt: 2)

        player.setRepeat(.all)

        #expect(engine.preloadedItem?.id == player.entries[0].id)
    }

    @Test func previous_pastThresholdRestartsCurrentSong() {
        let player = makePlayer()
        player.play(songs: songs, startingAt: 1)
        engine.emit(.progressed(position: 10, duration: 200))

        player.previous()

        #expect(player.currentSong?.id == "b" && engine.lastSeekPosition == 0)
    }

    @Test func previous_withinThresholdGoesToPreviousSong() {
        let player = makePlayer()
        player.play(songs: songs, startingAt: 1)
        engine.emit(.progressed(position: 2, duration: 200))

        player.previous()

        #expect(player.currentSong?.id == "a")
    }

    @Test func failure_whilePlayingSkipsToNextSong() throws {
        let player = makePlayer()
        player.play(songs: songs)
        let failedItem = try #require(engine.loadedItem)

        engine.emit(.failed(itemID: failedItem.id, message: "Unsupported format"))

        #expect(player.currentSong?.id == "b" && player.error?.songTitle == "Song a")
    }

    @Test func failure_ofEverySongStopsInsteadOfLooping() throws {
        let player = makePlayer()
        player.setRepeat(.all)
        player.play(songs: songs)

        for _ in songs {
            let failedItem = try #require(engine.loadedItem)
            engine.emit(.failed(itemID: failedItem.id, message: "Offline"))
        }

        #expect(!player.isPlaying)
    }

    @Test func addToQueue_onEmptyQueueStartsPlaying() {
        let player = makePlayer()

        player.addToQueue(songs)

        #expect(player.isPlaying && player.currentSong?.id == "a")
    }

    @Test func removingCurrentEntry_loadsTheSongAfterIt() {
        let player = makePlayer()
        player.play(songs: songs)

        player.remove(atOffsets: [0])

        #expect(engine.loadedItem?.id == player.entries[0].id && player.currentSong?.id == "b")
    }

    @Test func restoreSavedQueue_loadsPausedAtSavedPosition() async {
        let directory = makeTemporaryDirectory()
        let previousLaunch = makePlayer(queueStore: QueueStore(directory: directory))
        previousLaunch.play(songs: songs, startingAt: 1)
        engine.emit(.progressed(position: 42, duration: 200))
        await previousLaunch.saveQueue()
        let relaunchedEngine = FakeEngine()
        let relaunched = PlayerController(
            engine: relaunchedEngine,
            streamURL: Self.streamURL,
            queueStore: QueueStore(directory: directory)
        )

        await relaunched.restoreSavedQueue()

        #expect(!relaunchedEngine.isPlaying && relaunched.currentSong?.id == "b" && relaunchedEngine.loadedStartPosition == 42)
    }

    private func makePlayer(queueStore: QueueStore? = nil) -> PlayerController {
        PlayerController(engine: engine, streamURL: Self.streamURL, queueStore: queueStore)
    }

    private static func streamURL(for song: Song) -> URL {
        URL(filePath: "/stream/\(song.id)")
    }
}
