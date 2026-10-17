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
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
    }
}
