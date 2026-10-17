import SwiftUI

/// Login until a session exists, then the platform's library UI.
struct RootView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        if let session = appModel.session {
            LibraryRootView()
                .environment(session.library)
                .environment(session.player)
                .environment(\.imageCache, session.imageCache)
                .environment(\.playbackActions, PlaybackActions(player: session.player))
                .favoriteErrorAlert(library: session.library)
                #if DEBUG
                .task(id: session.id) {
                    await session.startup.value
                    await LaunchOptions.playRequestedAlbum(library: session.library, player: session.player)
                }
                #endif
                .onChange(of: scenePhase) { _, newPhase in
                    handleScenePhase(newPhase, in: session)
                }
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
