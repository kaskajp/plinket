import Foundation
import Library
import Observation
import OSLog
import Playback
import Subsonic

/// Everything that exists only while signed in to a server.
@MainActor
struct SignedInSession: Identifiable {
    let id = UUID()
    let config: ServerConfig
    let client: SubsonicClient
    let library: LibraryStore
    let imageCache: ImageCache
    let player: PlayerController
    let scrobbler: Scrobbler
    let queueStore: QueueStore
    let nowPlaying: NowPlayingBridge
    /// Restores the saved queue and cached library, then revalidates the library. Starts with the session, so it
    /// runs once whichever scene (phone or CarPlay) comes up first.
    let startup: Task<Void, Never>

    init(config: ServerConfig, password: String) {
        self.config = config
        client = SubsonicClient(config: config, password: password)
        let library = LibraryStore(client: client)
        self.library = library
        let imageCache = ImageCache(client: client)
        self.imageCache = imageCache
        let scrobbler = Scrobbler(submitter: client)
        self.scrobbler = scrobbler
        queueStore = QueueStore()
        let player = PlayerController(client: client, scrobbler: scrobbler, queueStore: queueStore)
        self.player = player
        nowPlaying = NowPlayingBridge(player: player) { coverArtID in
            try? await imageCache.image(coverArtID: coverArtID, pixelSize: SignedInSession.nowPlayingArtworkPixelSize)
        }
        startup = Task {
            await player.restoreSavedQueue()
            scrobbler.flushPending()
            await library.loadCachedSnapshots()
            await library.refreshAll()
        }
    }

    private static let nowPlayingArtworkPixelSize = 1024

    /// Stops playback and deletes everything this session stored on disk.
    func tearDown() async {
        startup.cancel()
        nowPlaying.invalidate()
        player.shutDown()
        await queueStore.remove()
        await scrobbler.removePending()
        await library.removeCachedData()
        await imageCache.removeAll()
    }
}

enum SignInError: LocalizedError {
    case invalidServerAddress
    case plainHTTPOutsideLocalNetwork

    var errorDescription: String? {
        switch self {
        case .invalidServerAddress:
            String(localized: "Enter a server address and a username, e.g. music.example.com.")
        case .plainHTTPOutsideLocalNetwork:
            String(localized: "Plain HTTP only works for servers on your local network. Use an https:// address.")
        }
    }
}

/// Owns sign-in state and the signed-in session.
@MainActor
@Observable
final class AppModel {
    /// Shared by every scene, because CarPlay can launch the app without the phone UI.
    static let shared = AppModel()

    private(set) var session: SignedInSession?

    @ObservationIgnored private let credentialStore = CredentialStore()

    private init() {
        session = restoredSession()
    }

    /// Validates the credentials with a ping before persisting them.
    func signIn(serverAddress: String, username: String, password: String) async throws {
        let config: ServerConfig
        do {
            config = try ServerConfig(serverAddress: serverAddress, username: username)
        } catch .invalid {
            throw SignInError.invalidServerAddress
        } catch .plainHTTPOutsideLocalNetwork {
            throw SignInError.plainHTTPOutsideLocalNetwork
        }
        try await SubsonicClient(config: config, password: password).ping()
        try credentialStore.savePassword(password, for: config)
        try credentialStore.saveServerConfig(config)
        session = SignedInSession(config: config, password: password)
    }

    func signOut() async {
        guard let session else { return }
        self.session = nil
        credentialStore.deleteServerConfig()
        do {
            try credentialStore.deletePassword(for: session.config)
        } catch {
            Logger.app.error("Could not delete saved password: \(error)")
        }
        await session.tearDown()
    }

    private func restoredSession() -> SignedInSession? {
        guard let config = credentialStore.serverConfig() else { return nil }
        do {
            guard let password = try credentialStore.password(for: config) else { return nil }
            return SignedInSession(config: config, password: password)
        } catch {
            Logger.app.error("Could not read saved password: \(error)")
            return nil
        }
    }
}

extension Logger {
    static let app = Logger(subsystem: "nu.4z.plinket", category: "App")
}
