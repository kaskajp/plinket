import SwiftUI

/// The signed-in account and sign-out.
struct SettingsView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        Form {
            if let config = appModel.session?.config {
                Section("Server") {
                    LabeledContent("Address", value: config.baseURL.absoluteString)
                    LabeledContent("Username", value: config.username)
                }
                Section {
                    Button("Sign Out", role: .destructive) {
                        Task { await appModel.signOut() }
                    }
                }
            } else {
                Text("Not signed in.")
                    .foregroundStyle(.secondary)
            }
            #if os(iOS)
            // macOS has About Plinket in the app menu instead.
            Section {
                NavigationLink("About Plinket") {
                    AboutView()
                }
            }
            #endif
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
    }
}
