import Foundation
@testable import Playback
import Subsonic

func makeTemporaryDirectory() -> URL {
    FileManager.default.temporaryDirectory.appending(path: "PlinketTests-\(UUID().uuidString)")
}

func makeSong(_ id: String, duration: Int? = 200) -> Song {
    Song(id: id, title: "Song \(id)", duration: duration)
}

/// Records every scrobble call; submissions fail while `isOffline` is set.
actor RecordingSubmitter: ScrobbleSubmitter {
    struct Call: Equatable {
        let songID: Song.ID
        let playedAt: Date
        let submission: Bool
    }

    private(set) var calls: [Call] = []
    private var isOffline = false

    var submittedSongIDs: [Song.ID] {
        calls.filter(\.submission).map(\.songID)
    }

    func setOffline(_ isOffline: Bool) {
        self.isOffline = isOffline
    }

    func scrobble(songID: Song.ID, playedAt: Date, submission: Bool) async throws {
        calls.append(Call(songID: songID, playedAt: playedAt, submission: submission))
        guard isOffline else { return }
        throw URLError(.notConnectedToInternet)
    }
}

/// A clock that only moves when told to.
@MainActor
final class ManualClock {
    var now = Date(timeIntervalSince1970: 1_700_000_000)

    func advance(by seconds: TimeInterval) {
        now += seconds
    }
}

/// Records what the controller asks of the engine and lets tests emit engine events.
@MainActor
final class FakeEngine: PlaybackEngine {
    var onEvent: (@MainActor (PlaybackEngineEvent) -> Void)?
    private(set) var loadCount = 0
    private(set) var loadedItem: PlaybackItem?
    private(set) var loadedStartPosition: TimeInterval?
    private(set) var preloadedItem: PlaybackItem?
    private(set) var isPlaying = false
    private(set) var lastSeekPosition: TimeInterval?

    func load(_ current: PlaybackItem, startingAt position: TimeInterval, next: PlaybackItem?) {
        loadCount += 1
        loadedItem = current
        loadedStartPosition = position
        preloadedItem = next
    }

    func preload(next: PlaybackItem?) {
        preloadedItem = next
    }

    func play() {
        isPlaying = true
    }

    func pause() {
        isPlaying = false
    }

    func seek(to position: TimeInterval) {
        lastSeekPosition = position
    }

    func stop() {
        isPlaying = false
        loadedItem = nil
        preloadedItem = nil
    }

    func emit(_ event: PlaybackEngineEvent) {
        onEvent?(event)
    }

    /// Simulates the current item playing to its end and the preloaded item taking over.
    func finishCurrentItem() {
        guard let preloadedItem else {
            emit(.reachedEnd)
            return
        }
        loadedItem = preloadedItem
        self.preloadedItem = nil
        emit(.advanced(to: preloadedItem.id))
    }
}
