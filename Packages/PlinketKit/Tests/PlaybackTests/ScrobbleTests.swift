import Foundation
import Testing
@testable import Playback

@Suite struct ScrobblePolicyTests {
    private let policy = ScrobblePolicy()

    @Test(arguments: [10.0, 29.9, 30.0])
    func shouldSubmit_neverForTracksUpToThirtySeconds(duration: TimeInterval) {
        #expect(!policy.shouldSubmit(playedSeconds: duration, durationSeconds: duration))
    }

    @Test func shouldSubmit_shortTrackAtHalfway() {
        #expect(policy.shouldSubmit(playedSeconds: 15.5, durationSeconds: 31))
    }

    @Test func shouldSubmit_notBeforeHalfway() {
        #expect(!policy.shouldSubmit(playedSeconds: 99.9, durationSeconds: 200))
    }

    @Test func shouldSubmit_atHalfway() {
        #expect(policy.shouldSubmit(playedSeconds: 100, durationSeconds: 200))
    }

    @Test func shouldSubmit_longTrackAtFourMinutesBeforeHalfway() {
        #expect(policy.shouldSubmit(playedSeconds: 240, durationSeconds: 1200))
    }

    @Test func shouldSubmit_longTrackNotJustBeforeFourMinutes() {
        #expect(!policy.shouldSubmit(playedSeconds: 239.9, durationSeconds: 1200))
    }

    @Test(arguments: [nil, 0.0, -1.0])
    func shouldSubmit_unknownDurationAtFourMinutes(duration: TimeInterval?) {
        #expect(policy.shouldSubmit(playedSeconds: 240, durationSeconds: duration))
    }

    @Test(arguments: [nil, 0.0, -1.0])
    func shouldSubmit_unknownDurationNotBeforeFourMinutes(duration: TimeInterval?) {
        #expect(!policy.shouldSubmit(playedSeconds: 239.9, durationSeconds: duration))
    }
}

@Suite struct ListeningTrackerTests {
    @Test func update_firstPositionCountsNothing() {
        var tracker = ListeningTracker()
        tracker.update(position: 1.5)
        #expect(tracker.listenedSeconds == 0)
    }

    @Test func update_accumulatesSteadyProgress() {
        var tracker = ListeningTracker()
        for position in stride(from: 0.0, through: 10.0, by: 0.5) {
            tracker.update(position: position)
        }
        #expect(tracker.listenedSeconds == 10)
    }

    @Test func update_countsStepAtMaximum() {
        var tracker = ListeningTracker(maximumContinuousStep: 2)
        tracker.update(position: 0)
        tracker.update(position: 2)
        #expect(tracker.listenedSeconds == 2)
    }

    @Test func update_ignoresForwardSeek() {
        var tracker = ListeningTracker()
        tracker.update(position: 0)
        tracker.update(position: 1)
        tracker.update(position: 120)
        #expect(tracker.listenedSeconds == 1)
    }

    @Test func update_resumesCountingAfterForwardSeek() {
        var tracker = ListeningTracker()
        tracker.update(position: 0)
        tracker.update(position: 120)
        tracker.update(position: 121)
        #expect(tracker.listenedSeconds == 1)
    }

    @Test func update_ignoresBackwardSeek() {
        var tracker = ListeningTracker()
        tracker.update(position: 30)
        tracker.update(position: 31)
        tracker.update(position: 30.5)
        #expect(tracker.listenedSeconds == 1)
    }

    @Test func update_countsRelisteningAfterBackwardSeek() {
        var tracker = ListeningTracker()
        tracker.update(position: 30)
        tracker.update(position: 31)
        tracker.update(position: 0)
        tracker.update(position: 1)
        #expect(tracker.listenedSeconds == 2)
    }

    @Test func update_samePositionWhilePausedCountsNothing() {
        var tracker = ListeningTracker()
        tracker.update(position: 5)
        tracker.update(position: 5)
        tracker.update(position: 5)
        #expect(tracker.listenedSeconds == 0)
    }
}

@Suite struct PendingScrobblesTests {
    private let firstPlay = PendingScrobble(songID: "song-1", playedAt: Date(timeIntervalSince1970: 1_000))
    private let secondPlay = PendingScrobble(songID: "song-2", playedAt: Date(timeIntervalSince1970: 2_000))

    @Test func enqueue_keepsInsertionOrder() {
        var pending = PendingScrobbles()
        pending.enqueue(secondPlay)
        pending.enqueue(firstPlay)
        #expect(pending.scrobbles == [secondPlay, firstPlay])
    }

    @Test func enqueue_ignoresSameSongAtSameTime() {
        var pending = PendingScrobbles([firstPlay])
        pending.enqueue(PendingScrobble(songID: firstPlay.songID, playedAt: firstPlay.playedAt))
        #expect(pending.scrobbles == [firstPlay])
    }

    @Test func enqueue_keepsSameSongPlayedAtDifferentTimes() {
        var pending = PendingScrobbles([firstPlay])
        let replay = PendingScrobble(songID: firstPlay.songID, playedAt: firstPlay.playedAt.addingTimeInterval(300))
        pending.enqueue(replay)
        #expect(pending.scrobbles == [firstPlay, replay])
    }

    @Test func enqueueContentsOf_requeuesFailedBatchWithoutDuplicates() {
        var pending = PendingScrobbles([firstPlay])
        pending.enqueue(contentsOf: [firstPlay, secondPlay])
        #expect(pending.scrobbles == [firstPlay, secondPlay])
    }

    @Test func init_dropsDuplicates() {
        let pending = PendingScrobbles([firstPlay, secondPlay, firstPlay])
        #expect(pending.scrobbles == [firstPlay, secondPlay])
    }

    @Test func dequeueAll_returnsEverythingPending() {
        var pending = PendingScrobbles([firstPlay, secondPlay])
        #expect(pending.dequeueAll() == [firstPlay, secondPlay])
    }

    @Test func dequeueAll_leavesQueueEmpty() {
        var pending = PendingScrobbles([firstPlay, secondPlay])
        _ = pending.dequeueAll()
        #expect(pending.isEmpty)
    }

    @Test func codable_roundTrips() throws {
        let pending = PendingScrobbles([firstPlay, secondPlay])
        let decoded = try JSONDecoder().decode(PendingScrobbles.self, from: JSONEncoder().encode(pending))
        #expect(decoded == pending)
    }
}
