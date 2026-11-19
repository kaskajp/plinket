import SwiftUI

/// Opens the native About screen, including the in-app problem report form.
struct AboutCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("About Plinket") {
                openWindow(id: "about")
            }
        }
    }
}
