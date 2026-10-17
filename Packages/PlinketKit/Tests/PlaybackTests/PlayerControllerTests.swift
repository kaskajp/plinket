import Foundation
@testable import Playback
import Subsonic
import Testing

@MainActor
struct PlayerControllerTests {
    private let engine = FakeEngine()
    private let songs = [makeSong("a"), makeSong("b"), makeSong("c")]

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
