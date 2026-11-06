import Downloads
import Subsonic
import SwiftUI

struct DownloadSettingsSections: View {
    let downloads: DownloadManager

    @Environment(\.scenePhase) private var scenePhase
    @State private var confirmsDeletion = false

    var body: some View {
        Section {
            Toggle("Enable downloads", isOn: setting(\.isEnabled))
            Picker("Download format", selection: setting(\.format)) {
                ForEach(DownloadFormat.allCases) { format in
                    Text(format.title).tag(format)
                }
            }
            Toggle("Allow downloads on cellular", isOn: setting(\.allowsCellular))
            Picker("Max Storage", selection: setting(\.maximumBytes)) {
                ForEach(storageLimits, id: \.self) { bytes in
                    Text(byteCount(bytes)).tag(bytes)
                }
            }
        } header: {
            Text("Downloads")
        } footer: {
            Text("Format changes apply to newly queued downloads. Opus and MP3 require server support and must be playable on this device. Expensive networks, including hotspots, follow the cellular setting. Transfers run while the app is active; interrupted downloads can be retried. Disabling downloads keeps completed music.")
        }
        .disabled(downloads.isDeleting)

        Section("Download Storage") {
            LabeledContent("Space used", value: byteCount(downloads.storage.usedBytes))
            LabeledContent("Free device space", value: downloads.storage.freeBytes.map(byteCount) ?? "Unavailable")
            LabeledContent("Songs", value: String(downloads.storage.songCount))
            LabeledContent("Albums", value: String(downloads.storage.albumCount))
            LabeledContent("Artists", value: String(downloads.storage.artistCount))
            Button("Delete all downloads", role: .destructive) { confirmsDeletion = true }
                .disabled(downloads.isDeleting || (downloads.completed.isEmpty && downloads.pendingSongIDs.isEmpty))
            if let error = downloads.errorMessage {
                Text(error).foregroundStyle(.red)
            }
        }
        .confirmationDialog("Delete all downloaded music from this device?", isPresented: $confirmsDeletion, titleVisibility: .visible) {
            Button("Delete all downloads", role: .destructive) {
                Task { await downloads.deleteAll() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your music on the server will not be deleted. Pending downloads will be cancelled.")
        }
        .task { downloads.refreshStorage() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { downloads.refreshStorage() }
        }
    }

    private var storageLimits: [Int64] {
        Set([1_000_000_000, 5_000_000_000, 10_000_000_000, 20_000_000_000, 50_000_000_000, downloads.settings.maximumBytes]).sorted()
    }

    private func setting<Value>(_ key: WritableKeyPath<DownloadSettings, Value>) -> Binding<Value> {
        Binding {
            downloads.settings[keyPath: key]
        } set: { value in
            var settings = downloads.settings
            settings[keyPath: key] = value
            downloads.updateSettings(settings)
        }
    }

    private func byteCount(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
