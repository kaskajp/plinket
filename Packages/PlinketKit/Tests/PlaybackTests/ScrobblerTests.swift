import Foundation
@testable import Playback
import Subsonic
import Testing

@MainActor
struct ScrobblerTests {
    private let directory = makeTemporaryDirectory()
    private let submitter = RecordingSubmitter()
    private let clock = ManualClock()

    @Test func trackStarted_announcesNowPlaying() async {
        let scrobbler = makeScrobbler()

        scrobbler.trackStarted(songID: "a", durationSeconds: 200)
        await scrobbler.waitUntilIdle()

        #expect(await submitter.calls == [.init(songID: "a", playedAt: clock.now, submission: false)])
    }

    @Test func positionChanged_submitsOncePerPlay() async {
        let scrobbler = makeScrobbler()
        scrobbler.trackStarted(songID: "a", durationSeconds: 200)

        listen(scrobbler, through: 200)
        await scrobbler.waitUntilIdle()

        #expect(await submitter.submittedSongIDs == ["a"])
    }

    @Test func positionChanged_submitsWithTimeThePlayStarted() async {
        let scrobbler = makeScrobbler()
        let startedAt = clock.now
        scrobbler.trackStarted(songID: "a", durationSeconds: 200)
        clock.advance(by: 100)

        listen(scrobbler, through: 100)
        await scrobbler.waitUntilIdle()

        #expect(await submitter.calls.last == .init(songID: "a", playedAt: startedAt, submission: true))
    }

    @Test func positionChanged_doesNotSubmitBeforeThreshold() async {
        let scrobbler = makeScrobbler()
        scrobbler.trackStarted(songID: "a", durationSeconds: 200)

        listen(scrobbler, through: 90)
        await scrobbler.waitUntilIdle()

        #expect(await submitter.submittedSongIDs.isEmpty)
    }

    @Test func trackStarted_againForSameSongCountsAsNewPlay() async {
        let scrobbler = makeScrobbler()
        scrobbler.trackStarted(songID: "a", durationSeconds: 200)
        listen(scrobbler, through: 200)
        clock.advance(by: 200)

        scrobbler.trackStarted(songID: "a", durationSeconds: 200)
        listen(scrobbler, through: 200)
        await scrobbler.waitUntilIdle()

        #expect(await submitter.submittedSongIDs == ["a", "a"])
    }

    @Test func failedSubmission_isRetriedOnNextLaunch() async {
        await submitter.setOffline(true)
        let offlineScrobbler = makeScrobbler()
        offlineScrobbler.trackStarted(songID: "a", durationSeconds: 200)
        listen(offlineScrobbler, through: 100)
        await offlineScrobbler.waitUntilIdle()
        await submitter.setOffline(false)
        let relaunchedSubmitter = RecordingSubmitter()
        let relaunchedScrobbler = Scrobbler(submitter: relaunchedSubmitter, directory: directory)

        relaunchedScrobbler.flushPending()
        await relaunchedScrobbler.waitUntilIdle()

        #expect(await relaunchedSubmitter.submittedSongIDs == ["a"])
    }

    @Test func successfulSubmission_alsoSubmitsPendingOnes() async {
        let scrobbler = makeScrobbler()
        await submitter.setOffline(true)
        scrobbler.trackStarted(songID: "a", durationSeconds: 200)
        listen(scrobbler, through: 100)
        await scrobbler.waitUntilIdle()
        await submitter.setOffline(false)

        scrobbler.trackStarted(songID: "b", durationSeconds: 200)
        listen(scrobbler, through: 100)
        await scrobbler.waitUntilIdle()

        #expect(await submitter.submittedSongIDs == ["a", "b", "a"])
    }

    @Test func removePending_discardsQueuedSubmissions() async {
        await submitter.setOffline(true)
        let scrobbler = makeScrobbler()
        scrobbler.trackStarted(songID: "a", durationSeconds: 200)
        listen(scrobbler, through: 100)
        await scrobbler.removePending()
        await submitter.setOffline(false)
        let relaunchedSubmitter = RecordingSubmitter()
        let relaunchedScrobbler = Scrobbler(submitter: relaunchedSubmitter, directory: directory)

        relaunchedScrobbler.flushPending()
        await relaunchedScrobbler.waitUntilIdle()

        #expect(await relaunchedSubmitter.submittedSongIDs.isEmpty)
    }

    private func makeScrobbler() -> Scrobbler {
        Scrobbler(submitter: submitter, directory: directory, now: { [clock] in clock.now })
    }

    private func listen(_ scrobbler: Scrobbler, through seconds: TimeInterval) {
        for position in stride(from: 0.0, through: seconds, by: 0.5) {
            scrobbler.positionChanged(to: position)
        }
    }
}
