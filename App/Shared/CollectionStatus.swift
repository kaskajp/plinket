import Library
import Subsonic
import SwiftUI

/// What a collection shows while it has nothing to list: loading, the refresh error, or that it is empty.
struct CollectionPlaceholder: View {
    let collection: LibraryCollection
    let isRefreshing: Bool
    let error: SubsonicError?
    let retry: () -> Void

    var body: some View {
        if isRefreshing {
            ProgressView(collection.loadingTitle)
        } else if let error {
            ContentUnavailableView {
                Label(collection.failureTitle, systemImage: "exclamationmark.triangle")
            } description: {
                Text(error.localizedDescription)
            } actions: {
                Button("Try Again", action: retry)
            }
        } else {
            ContentUnavailableView(collection.emptyTitle, systemImage: collection.systemImage)
        }
    }
}

extension View {
    /// Keeps stale content visible while telling the user the last refresh failed.
    func refreshErrorBanner(_ error: SubsonicError?) -> some View {
        safeAreaInset(edge: .bottom) {
            if let error {
                RefreshErrorBanner(message: error.localizedDescription)
            }
        }
    }
}

private struct RefreshErrorBanner: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "exclamationmark.triangle")
            .font(.footnote)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.regularMaterial, in: .capsule)
            .padding(.bottom, 8)
    }
}

private extension LibraryCollection {
    var loadingTitle: LocalizedStringKey {
        switch self {
        case .albums: "Loading Albums…"
        case .artists: "Loading Artists…"
        case .playlists: "Loading Playlists…"
        case .starred: "Loading Favorites…"
        }
    }

    var failureTitle: LocalizedStringKey {
        switch self {
        case .albums: "Couldn’t Load Albums"
        case .artists: "Couldn’t Load Artists"
        case .playlists: "Couldn’t Load Playlists"
        case .starred: "Couldn’t Load Favorites"
        }
    }

    var emptyTitle: LocalizedStringKey {
        switch self {
        case .albums: "No Albums"
        case .artists: "No Artists"
        case .playlists: "No Playlists"
        case .starred: "No Favorites"
        }
    }

    var systemImage: String {
        switch self {
        case .albums: "square.stack"
        case .artists: "music.mic"
        case .playlists: "music.note.list"
        case .starred: "star"
        }
    }
}
