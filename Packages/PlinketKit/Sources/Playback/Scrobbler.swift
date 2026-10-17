import Foundation
import OSLog
import Subsonic

/// Reports plays to a server.
public protocol ScrobbleSubmitter: Sendable {
    /// `submission: false` announces "now playing"; `true` records a finished listen started at `playedAt`.
    func scrobble(songID: Song.ID, playedAt: Date, submission: Bool) async throws
}

extension SubsonicClient: ScrobbleSubmitter {}

/// Announces what is playing and submits each play once it has been listened to long enough.
///
/// Failed submissions are kept on disk and retried after the next successful one or on ``flushPending()``.
@MainActor
public final class Scrobbler {
    static let fileName = "pending-scrobbles.json"

    private let submitter: any ScrobbleSubmitter
    private let policy: ScrobblePolicy
    private let now: @MainActor () -> Date
    private let pendingFile: JSONFile<PendingScrobbles>
    private var pending = PendingScrobbles()
    /// The play still waiting to reach the submission threshold; `nil` once submitted.
    private var unsubmittedPlay: Play?
    /// Network work runs one item at a time, in the order it was requested.
    private var lastWork: Task<Void, Never>?

    public init(
        submitter: any ScrobbleSubmitter,
        directory: URL = PlaybackStorage.defaultDirectory,
        policy: ScrobblePolicy = ScrobblePolicy(),
        now: @escaping @MainActor () -> Date = Date.init
    ) {
        self.submitter = submitter
        self.policy = policy
        self.now = now
        pendingFile = JSONFile(url: directory.appending(path: Self.fileName))
        enqueueWork { await self.loadPending() }
    }

    /// Starts a new play of `songID`; call it again for a replay of the same song.
    public func trackStarted(songID: Song.ID, durationSeconds: TimeInterval?) {
        let play = Play(songID: songID, startedAt: now(), durationSeconds: durationSeconds)
        unsubmittedPlay = play
        enqueueWork { await self.announceNowPlaying(play) }
    }

    /// Feeds the current play's position; submits the play the first time it crosses the threshold.
    public func positionChanged(to position: TimeInterval) {
        guard var play = unsubmittedPlay else { return }
        play.tracker.update(position: position)
        guard policy.shouldSubmit(playedSeconds: play.tracker.listenedSeconds, durationSeconds: play.durationSeconds) else {
            unsubmittedPlay = play
            return
        }
        unsubmittedPlay = nil
        let scrobble = PendingScrobble(songID: play.songID, playedAt: play.startedAt)
        enqueueWork { await self.submit(scrobble) }
    }

    /// Retries every submission that failed earlier.
    public func flushPending() {
        enqueueWork { await self.submitPending() }
    }

    /// Forgets the current play and deletes queued submissions, e.g. on sign-out.
    public func removePending() async {
        unsubmittedPlay = nil
        enqueueWork {
            self.pending = PendingScrobbles()
            await self.pendingFile.remove()
        }
        await waitUntilIdle()
    }

    func waitUntilIdle() async {
        await lastWork?.value
    }

    private func enqueueWork(_ work: @escaping @MainActor () async -> Void) {
        let previousWork = lastWork
        lastWork = Task {
            await previousWork?.value
            await work()
        }
    }

    private func loadPending() async {
        guard let saved = await pendingFile.load() else { return }
        pending.enqueue(contentsOf: saved.scrobbles)
    }

    private func announceNowPlaying(_ play: Play) async {
        do {
            try await submitter.scrobble(songID: play.songID, playedAt: play.startedAt, submission: false)
        } catch {
            Logger.playback.info("Could not announce now playing: \(error)")
        }
    }

    private func submit(_ scrobble: PendingScrobble) async {
        do {
            try await send(scrobble)
        } catch {
            Logger.playback.info("Queueing scrobble for retry: \(error)")
            pending.enqueue(scrobble)
            await pendingFile.save(pending)
            return
        }
        await submitPending()
    }

    private func submitPending() async {
        guard !pending.isEmpty else { return }
        var remaining = pending.dequeueAll()[...]
        while let scrobble = remaining.first {
            do {
                try await send(scrobble)
            } catch {
                pending.enqueue(contentsOf: remaining)
                break
            }
            remaining.removeFirst()
        }
        await pendingFile.save(pending)
    }

    private func send(_ scrobble: PendingScrobble) async throws {
        try await submitter.scrobble(songID: scrobble.songID, playedAt: scrobble.playedAt, submission: true)
    }

    private struct Play {
        let songID: Song.ID
        let startedAt: Date
        let durationSeconds: TimeInterval?
        var tracker = ListeningTracker()
    }
}
