import Downloads
import Subsonic
import SwiftUI

/// The durable offline library, independent of server requests and evictable library caches.
struct DownloadsView: View {
    @Environment(DownloadManager.self) private var downloads

    var body: some View {
        let songs = downloads.completed.map(\.song)
        List {
            if !songs.isEmpty {
                DownloadStatus()
                ForEach(Array(songs.enumerated()), id: \.element.id) { index, song in
                    PlayableSong(songs: songs, index: index) {
                        SongRow(song: song)
                    }
                }
            } else {
                ContentUnavailableView(
                    "No Downloads", systemImage: "arrow.down.circle",
                    description: Text("Download an album or use a song’s menu to keep music for offline playback.")
                )
                DownloadStatus()
            }
        }
        .navigationTitle("Downloads")
    }
}

struct DownloadButton: View {
    let songs: [Song]

    @Environment(DownloadManager.self) private var downloads

    var body: some View {
        let completed = !songs.isEmpty && songs.allSatisfy { downloads.localURL(for: $0.id) != nil }
        let pending = songs.contains { downloads.pendingSongIDs.contains($0.id) }
        Button {
            downloads.enqueue(songs)
        } label: {
            if completed {
                Label("Downloaded", systemImage: "checkmark.circle")
            } else if pending {
                Label(downloads.isWaitingForNetwork ? "Waiting for Network" : "Downloading…", systemImage: "arrow.down.circle.dotted")
            } else {
                Label(songs.count == 1 ? "Download Song" : "Download Album", systemImage: "arrow.down.circle")
            }
        }
        .disabled(songs.isEmpty || completed || pending || !downloads.settings.isEnabled || downloads.isDeleting)
    }
}

private struct DownloadStatus: View {
    @Environment(DownloadManager.self) private var downloads

    var body: some View {
        if downloads.isWaitingForNetwork {
            Label("Downloads paused. Waiting for an allowed network.", systemImage: "wifi.slash")
                .foregroundStyle(.secondary)
        } else if !downloads.pendingSongIDs.isEmpty {
            Label("Downloading \(downloads.pendingSongIDs.count) songs…", systemImage: "arrow.down.circle")
                .foregroundStyle(.secondary)
        }
    }
}

extension View {
    func downloadErrorAlert(downloads: DownloadManager) -> some View {
        alert("Download Failed", isPresented: Binding(
            get: { downloads.errorMessage != nil },
            set: { if !$0 { downloads.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { downloads.errorMessage = nil }
        } message: {
            Text(downloads.errorMessage ?? "")
        }
    }
}
