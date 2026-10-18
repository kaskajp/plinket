#if os(iOS)
import AVFoundation
import OSLog

/// Configures the shared audio session for music playback and reacts to interruptions and route changes.
@MainActor
final class AudioSessionCoordinator {
    private let player: PlayerController
    private let session = AVAudioSession.sharedInstance()
    private var notificationObservers: [any NSObjectProtocol] = []
    private var wasPlayingBeforeInterruption = false

    init(player: PlayerController) {
        self.player = player
        do {
            try session.setCategory(.playback, mode: .default, policy: .longFormAudio)
        } catch {
            Logger.playback.error("Could not configure audio session: \(error)")
        }
        observeSessionNotifications()
    }

    func activate() {
        session.activate(options: []) { _, error in
            guard let error else { return }
            Logger.playback.error("Could not activate audio session: \(error)")
        }
    }

    func invalidate() {
        for observer in notificationObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        notificationObservers = []
        session.deactivate(options: .notifyOthersOnDeactivation) { _, error in
            guard let error else { return }
            Logger.playback.error("Could not deactivate audio session: \(error)")
        }
    }

    private func observeSessionNotifications() {
        let center = NotificationCenter.default
        notificationObservers = [
            center.addObserver(forName: AVAudioSession.didBecomeInactiveNotification, object: session, queue: .main) { [weak self] notification in
                guard let context = notification.userInfo?[AVAudioSession.deactivationContextKey] as? AVAudioSession.DeactivationContext,
                      context.source == .system
                else { return }
                MainActor.assumeIsolated { self?.handleSystemDeactivation() }
            },
            center.addObserver(forName: AVAudioSession.resumptionRecommendationNotification, object: session, queue: .main) { [weak self] notification in
                guard let context = notification.userInfo?[AVAudioSession.resumptionContextKey] as? AVAudioSession.ResumptionContext else { return }
                let recommendation = context.recommendation
                MainActor.assumeIsolated { self?.handleResumption(recommendation) }
            },
            center.addObserver(forName: AVAudioSession.routeChangeNotification, object: session, queue: .main) { [weak self] notification in
                guard let reasonValue = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                      let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue)
                else { return }
                MainActor.assumeIsolated { self?.handleRouteChange(reason) }
            },
        ]
    }

    /// The system took the session away, e.g. for a phone call.
    private func handleSystemDeactivation() {
        wasPlayingBeforeInterruption = player.isPlaying
        player.pause()
    }

    private func handleResumption(_ recommendation: AVAudioSession.ResumptionRecommendation) {
        guard wasPlayingBeforeInterruption, recommendation == .shouldResume else { return }
        wasPlayingBeforeInterruption = false
        player.play()
    }

    /// Unplugging headphones must not start playing out loud.
    private func handleRouteChange(_ reason: AVAudioSession.RouteChangeReason) {
        guard reason == .oldDeviceUnavailable else { return }
        player.pause()
    }
}
#endif
