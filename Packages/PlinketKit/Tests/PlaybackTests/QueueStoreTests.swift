import Foundation
@testable import Playback
import Subsonic
import Testing

@MainActor
struct QueueStoreTests {
    private let directory = makeTemporaryDirectory()

    @Test func flush_persistsPlaybackForNextLaunch() async {
        let playback = makePlayback(position: 42)
        let store = QueueStore(directory: directory)
        store.save(playback)

        await store.flush()

        #expect(await QueueStore(directory: directory).load() == playback)
    }

    @Test func save_writesAfterDelayWithoutFlush() async throws {
        let playback = makePlayback(position: 42)
        let store = QueueStore(directory: directory, saveDelay: .milliseconds(10))
        store.save(playback)

        try await Task.sleep(for: .milliseconds(200))

        #expect(await QueueStore(directory: directory).load() == playback)
    }

    @Test func save_keepsLatestOfCoalescedCalls() async {
        let store = QueueStore(directory: directory)
        store.save(makePlayback(position: 1))
        store.save(makePlayback(position: 2))

        await store.flush()

        #expect(await QueueStore(directory: directory).load()?.position == 2)
    }

    @Test func remove_discardsUnsavedChanges() async {
        let store = QueueStore(directory: directory, saveDelay: .milliseconds(10))
        store.save(makePlayback(position: 1))

        await store.remove()
        await store.flush()

        #expect(await QueueStore(directory: directory).load() == nil)
    }

    private func makePlayback(position: TimeInterval) -> SavedPlayback {
        var queue = PlayQueue<Song>(repeatMode: .all)
        queue.replace(with: [makeSong("a"), makeSong("b")], startingAt: 1)
        queue.setShuffle(true)
        return SavedPlayback(queue: queue, position: position)
    }
}
