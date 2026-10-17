import CoreGraphics
import Foundation
import MediaPlayer
import Subsonic
#if os(iOS)
import UIKit
#else
import AppKit
#endif

/// Mirrors the player into the system's Now Playing info (lock screen, Control Center) and routes
/// remote commands (media keys, headphones, lock screen buttons) back to it.
///
/// Call ``invalidate()`` when the player goes away; until then the command handlers keep it alive.
@MainActor
public final class NowPlayingBridge {
    public typealias ArtworkLoader = @Sendable (_ coverArtID: String) async -> CGImage?

    /// How far the system's extrapolated elapsed time may drift from the real position before it is corrected.
    private static let elapsedTimeTolerance: TimeInterval = 1.5

    private let player: PlayerController
    private let loadArtwork: ArtworkLoader
    private let infoCenter = MPNowPlayingInfoCenter.default()
    private var observationTask: Task<Void, Never>?
    private var artworkTask: Task<Void, Never>?
    private var commandTargets: [(command: MPRemoteCommand, target: Any)] = []
    private var published: PublishedState?
    private var artwork: MPMediaItemArtwork?
    #if os(iOS)
    private let audioSession: AudioSessionCoordinator
    #endif

    public init(player: PlayerController, loadArtwork: @escaping ArtworkLoader) {
        self.player = player
        self.loadArtwork = loadArtwork
        #if os(iOS)
        audioSession = AudioSessionCoordinator(player: player)
        #endif
        registerRemoteCommands()
        observePlayer()
    }

    public func invalidate() {
        observationTask?.cancel()
        artworkTask?.cancel()
        for (command, target) in commandTargets {
            command.removeTarget(target)
        }
        commandTargets = []
        published = nil
        infoCenter.nowPlayingInfo = nil
        infoCenter.playbackState = .stopped
        #if os(iOS)
        audioSession.invalidate()
        #endif
    }

    // MARK: - Now Playing info

    private func observePlayer() {
        let player = player
        observationTask = Task { [weak self] in
            for await state in Observations({ PlayerState(player) }) {
                self?.update(with: state)
            }
        }
    }

    private func update(with state: PlayerState) {
        publishPlaybackModes(of: state)
        guard needsPublishing(state) else { return }
        #if os(iOS)
        if state.isPlaying, published?.state.isPlaying != true {
            audioSession.activate()
        }
        #endif
        let isNewEntry = state.entryID != published?.state.entryID
        publish(state, keepingArtwork: !isNewEntry)
        if isNewEntry {
            loadArtwork(coverArtID: state.song?.coverArtID, for: state.entryID)
        }
    }

    /// Position ticks only matter when they disagree with what the system extrapolates from the last update.
    private func needsPublishing(_ state: PlayerState) -> Bool {
        guard let published else { return true }
        guard state.isSameTimeline(as: published.state) else { return true }
        let elapsedSincePublishing = state.isPlaying ? published.publishedAt.duration(to: .now).timeInterval : 0
        let expectedPosition = published.state.position + elapsedSincePublishing
        return abs(expectedPosition - state.position) > Self.elapsedTimeTolerance
    }

    private func publish(_ state: PlayerState, keepingArtwork: Bool) {
        published = PublishedState(state: state, publishedAt: .now)
        guard let song = state.song else {
            artwork = nil
            infoCenter.nowPlayingInfo = nil
            infoCenter.playbackState = .stopped
            return
        }
        if !keepingArtwork {
            artwork = nil
        }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: song.title,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: state.position,
            MPNowPlayingInfoPropertyPlaybackRate: state.isPlaying ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: 1.0,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue,
        ]
        info[MPMediaItemPropertyArtist] = song.artist
        info[MPMediaItemPropertyAlbumTitle] = song.album
        info[MPMediaItemPropertyPlaybackDuration] = state.duration
        info[MPMediaItemPropertyArtwork] = artwork
        infoCenter.nowPlayingInfo = info
        infoCenter.playbackState = state.isPlaying ? .playing : .paused
    }

    /// CarPlay's shuffle and repeat buttons draw their state from these.
    private func publishPlaybackModes(of state: PlayerState) {
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.changeShuffleModeCommand.currentShuffleType = state.isShuffled ? .items : .off
        commandCenter.changeRepeatModeCommand.currentRepeatType = state.repeatMode.remoteRepeatType
    }

    private func loadArtwork(coverArtID: String?, for entryID: UUID?) {
        artworkTask?.cancel()
        guard let coverArtID else { return }
        let loadArtwork = loadArtwork
        artworkTask = Task { [weak self] in
            guard let image = await loadArtwork(coverArtID), !Task.isCancelled else { return }
            self?.applyArtwork(Self.makeArtwork(from: image), for: entryID)
        }
    }

    private func applyArtwork(_ newArtwork: MPMediaItemArtwork, for entryID: UUID?) {
        guard published?.state.entryID == entryID, var info = infoCenter.nowPlayingInfo else { return }
        artwork = newArtwork
        info[MPMediaItemPropertyArtwork] = newArtwork
        infoCenter.nowPlayingInfo = info
    }

    /// Nonisolated so the request handler isn't main-actor bound: the system calls it from a background queue.
    private nonisolated static func makeArtwork(from image: CGImage) -> MPMediaItemArtwork {
        let size = CGSize(width: image.width, height: image.height)
        return MPMediaItemArtwork(boundsSize: size) { @Sendable _ in
            #if os(iOS)
            UIImage(cgImage: image)
            #else
            NSImage(cgImage: image, size: size)
            #endif
        }
    }

    // MARK: - Remote commands

    private func registerRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()
        addTarget(to: commandCenter.playCommand) { $0.play() }
        addTarget(to: commandCenter.pauseCommand) { $0.pause() }
        addTarget(to: commandCenter.togglePlayPauseCommand) { $0.togglePlayPause() }
        addTarget(to: commandCenter.nextTrackCommand) { $0.next() }
        addTarget(to: commandCenter.previousTrackCommand) { $0.previous() }

        let player = player
        let seekCommand = commandCenter.changePlaybackPositionCommand
        let seekTarget = seekCommand.addTarget { @Sendable event in
            guard let positionEvent = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            let position = positionEvent.positionTime
            Task { @MainActor in player.seek(to: position) }
            return .success
        }
        commandTargets.append((seekCommand, seekTarget))

        let shuffleCommand = commandCenter.changeShuffleModeCommand
        let shuffleTarget = shuffleCommand.addTarget { @Sendable event in
            guard let shuffleEvent = event as? MPChangeShuffleModeCommandEvent else { return .commandFailed }
            let isShuffled = shuffleEvent.shuffleType != .off
            Task { @MainActor in player.setShuffle(isShuffled) }
            return .success
        }
        commandTargets.append((shuffleCommand, shuffleTarget))

        let repeatCommand = commandCenter.changeRepeatModeCommand
        let repeatTarget = repeatCommand.addTarget { @Sendable event in
            guard let repeatEvent = event as? MPChangeRepeatModeCommandEvent else { return .commandFailed }
            let mode = RepeatMode(remoteRepeatType: repeatEvent.repeatType)
            Task { @MainActor in player.setRepeat(mode) }
            return .success
        }
        commandTargets.append((repeatCommand, repeatTarget))
    }

    /// Handlers may be called off the main thread, so they only schedule the action.
    private func addTarget(to command: MPRemoteCommand, action: @escaping @MainActor @Sendable (PlayerController) -> Void) {
        let player = player
        let target = command.addTarget { @Sendable _ in
            Task { @MainActor in action(player) }
            return .success
        }
        commandTargets.append((command, target))
    }
}

/// The parts of the player shown in Now Playing.
private struct PlayerState: Sendable, Equatable {
    let entryID: UUID?
    let song: Song?
    let isPlaying: Bool
    let position: TimeInterval
    let duration: TimeInterval?
    let isShuffled: Bool
    let repeatMode: RepeatMode

    @MainActor
    init(_ player: PlayerController) {
        entryID = player.queue.currentEntry?.id
        song = player.currentSong
        isPlaying = player.isPlaying
        position = player.position
        duration = player.duration
        isShuffled = player.isShuffled
        repeatMode = player.repeatMode
    }

    /// Equal apart from position, so the system's own extrapolation still holds.
    func isSameTimeline(as other: PlayerState) -> Bool {
        entryID == other.entryID && song == other.song && isPlaying == other.isPlaying && duration == other.duration
    }
}

private struct PublishedState {
    let state: PlayerState
    let publishedAt: ContinuousClock.Instant
}

private extension RepeatMode {
    init(remoteRepeatType: MPRepeatType) {
        switch remoteRepeatType {
        case .off: self = .off
        case .one: self = .one
        case .all: self = .all
        @unknown default: self = .off
        }
    }

    var remoteRepeatType: MPRepeatType {
        switch self {
        case .off: .off
        case .one: .one
        case .all: .all
        }
    }
}

private extension Duration {
    var timeInterval: TimeInterval {
        let (seconds, attoseconds) = components
        return TimeInterval(seconds) + TimeInterval(attoseconds) / 1e18
    }
}
