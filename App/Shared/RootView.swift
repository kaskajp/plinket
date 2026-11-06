import Downloads
import SwiftUI

/// Restores local state behind the splash screen, then shows sign-in or the library.
struct RootView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isLaunching = true

    var body: some View {
        ZStack {
            if isLaunching {
                SplashView()
            } else {
                content
            }
        }
        .task {
            await appModel.session?.restoration.value
            guard !Task.isCancelled else { return }
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
                isLaunching = false
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard let session = appModel.session else { return }
            handleScenePhase(newPhase, in: session)
        }
    }

    @ViewBuilder
    private var content: some View {
        if let session = appModel.session {
            LibraryRootView()
                .environment(session.library)
                .environment(session.player)
                .environment(session.downloads)
                .environment(\.imageCache, session.imageCache)
                .environment(\.playbackActions, PlaybackActions(player: session.player))
                .favoriteErrorAlert(library: session.library)
                .downloadErrorAlert(downloads: session.downloads)
                #if DEBUG
                .task(id: session.id) {
                    await session.startup.value
                    await LaunchOptions.playRequestedAlbum(library: session.library, player: session.player)
                }
                #endif
        } else {
            LoginView()
                #if DEBUG
                .task { await appModel.signInWithLaunchCredentials() }
                #endif
        }
    }

    private func handleScenePhase(_ phase: ScenePhase, in session: SignedInSession) {
        switch phase {
        case .active:
            session.scrobbler.flushPending()
        case .background:
            Task { await session.player.saveQueue() }
        default:
            return
        }
    }
}
