import SwiftUI

@main
struct PlinketApp: App {
    @State private var appModel = AppModel.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appModel)
                #if os(macOS) && DEBUG
                .writesLaunchWindowSnapshot()
                #endif
        }
        #if os(macOS)
        .defaultSize(width: 1100, height: 760)
        .commands {
            AboutCommands()
            PlaybackCommands(player: appModel.session?.player)
            LibraryCommands(library: appModel.session?.library)
        }
        #endif
        #if os(macOS)
        Settings {
            SettingsView()
                .environment(appModel)
        }
        #endif
    }
}
