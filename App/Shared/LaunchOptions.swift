import Foundation
import Library
import OSLog
import Playback
import Subsonic
import SwiftUI

/// Debug-build shortcuts for checking the UI without tapping through it, read from `PLINKET_DEBUG_*` environment
/// variables. Release builds always get the defaults.
enum LaunchOptions {
    static var initialSection: LibrarySection {
        value(for: "PLINKET_DEBUG_SECTION").flatMap(LibrarySection.init(rawValue:)) ?? .albums
    }

    static var searchQuery: String {
        value(for: "PLINKET_DEBUG_SEARCH") ?? ""
    }

    static var opensNowPlaying: Bool {
        value(for: "PLINKET_DEBUG_NOW_PLAYING") != nil
    }

    /// An album name fragment, or "first" for the first album in the grid.
    fileprivate static var albumToOpen: String? {
        value(for: "PLINKET_DEBUG_OPEN_ALBUM")
    }

    fileprivate static var albumToPlay: String? {
        value(for: "PLINKET_DEBUG_PLAY_ALBUM")
    }

    private static func value(for name: String) -> String? {
        #if DEBUG
        guard let value = ProcessInfo.processInfo.environment[name], !value.isEmpty else { return nil }
        return value
        #else
        nil
        #endif
    }

    fileprivate static func album(matching nameFragment: String, in albums: [Album]) -> Album? {
        guard nameFragment != "first" else { return albums.first }
        return albums.first { $0.name.localizedStandardContains(nameFragment) }
    }
}

#if DEBUG
extension LaunchOptions {
    struct Credentials {
        let serverAddress: String
        let username: String
        let password: String
    }

    static var credentials: Credentials? {
        guard let serverAddress = value(for: "PLINKET_DEBUG_SERVER"),
              let username = value(for: "PLINKET_DEBUG_USER"),
              let password = value(for: "PLINKET_DEBUG_PASSWORD")
        else { return nil }
        return Credentials(serverAddress: serverAddress, username: username, password: password)
    }

    /// Starts the requested album once the library has loaded.
    @MainActor
    static func playRequestedAlbum(library: LibraryStore, player: PlayerController) async {
        guard let albumToPlay, let album = album(matching: albumToPlay, in: library.albums) else { return }
        do {
            player.play(songs: try await library.albumDetail(id: album.id).songs)
        } catch {
            Logger.app.error("Launch playback failed: \(error)")
        }
    }
}

extension AppModel {
    /// Signs in with the launch environment's credentials, for simulator and screenshot runs.
    func signInWithLaunchCredentials() async {
        guard session == nil, let credentials = LaunchOptions.credentials else { return }
        do {
            try await signIn(serverAddress: credentials.serverAddress, username: credentials.username, password: credentials.password)
        } catch {
            Logger.app.error("Launch sign-in failed: \(error)")
        }
    }
}
#endif

extension View {
    /// Pushes the requested album onto the Albums stack once the library has it.
    func opensLaunchAlbum(in section: LibrarySection, path: Binding<NavigationPath>) -> some View {
        #if DEBUG
        modifier(LaunchAlbumOpener(isEnabled: section == .albums, path: path))
        #else
        self
        #endif
    }
}

#if DEBUG
private struct LaunchAlbumOpener: ViewModifier {
    let isEnabled: Bool
    @Binding var path: NavigationPath

    @Environment(LibraryStore.self) private var library
    @State private var hasOpened = false

    func body(content: Content) -> some View {
        content.onChange(of: library.albums.count, initial: true) {
            guard isEnabled, !hasOpened, let albumToOpen = LaunchOptions.albumToOpen,
                  let album = LaunchOptions.album(matching: albumToOpen, in: library.albums)
            else { return }
            hasOpened = true
            path.append(album)
        }
    }
}
#endif
