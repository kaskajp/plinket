import CryptoKit
import Foundation
import Network
import Observation
import Subsonic

/// Owns durable offline music, its settings, and a serial, connectivity-aware download queue.
@MainActor
@Observable
public final class DownloadManager {
    public private(set) var settings = DownloadSettings()
    public private(set) var completed: [DownloadedSong] = []
    public private(set) var storage = DownloadStorage(usedBytes: 0, freeBytes: nil, songCount: 0, albumCount: 0, artistCount: 0)
    public private(set) var pendingSongIDs: Set<Song.ID> = []
    public private(set) var isWaitingForNetwork = false
    public private(set) var isDeleting = false
    public var errorMessage: String?

    @ObservationIgnored private let directory: URL
    @ObservationIgnored private let sourceURL: @Sendable (Song.ID, DownloadFormat) -> URL
    @ObservationIgnored private let transfer: Transfer
    @ObservationIgnored private let freeSpace: @Sendable (URL) throws -> Int64
    @ObservationIgnored private var monitor: NWPathMonitor?
    @ObservationIgnored private var isConnected = false
    @ObservationIgnored private var isCellular = false
    @ObservationIgnored private var pending: [Request] = []
    @ObservationIgnored private var worker: Task<Void, Never>?
    @ObservationIgnored private var isReady = false

    typealias Transfer = @Sendable (URL, URL, Int64, Bool, DownloadFormat) async throws -> Void

    private struct Request {
        let song: Song
        let format: DownloadFormat
    }

    public convenience init(client: SubsonicClient) {
        self.init(
            directory: Self.directory(for: client.config),
            sourceURL: { client.downloadURL(songID: $0, format: $1) },
            transfer: { try await DownloadTransfer.fetch(from: $0, to: $1, maximumBytes: $2, allowsCellular: $3, format: $4) },
            freeSpace: Self.availableSpace
        )
        let monitor = NWPathMonitor()
        self.monitor = monitor
        monitor.pathUpdateHandler = { [weak self] path in
            let connected = path.status == .satisfied
            let cellular = path.usesInterfaceType(.cellular) || path.isExpensive
            Task { @MainActor [weak self] in self?.updateNetwork(isConnected: connected, isCellular: cellular) }
        }
        monitor.start(queue: DispatchQueue(label: "nu.4z.plinket.download-network"))
    }

    init(
        directory: URL,
        sourceURL: @escaping @Sendable (Song.ID, DownloadFormat) -> URL,
        transfer: @escaping Transfer,
        freeSpace: @escaping @Sendable (URL) throws -> Int64
    ) {
        self.directory = directory
        self.sourceURL = sourceURL
        self.transfer = transfer
        self.freeSpace = freeSpace
        restore()
    }

    isolated deinit {
        monitor?.cancel()
        worker?.cancel()
    }

    public func localURL(for songID: Song.ID) -> URL? {
        guard let download = completed.first(where: { $0.id == songID }) else { return nil }
        let url = directory.appending(path: download.filename)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    public func enqueue(_ songs: [Song]) {
        guard isReady, !isDeleting else { return }
        guard settings.isEnabled else {
            errorMessage = DownloadError.disabled.localizedDescription
            return
        }
        for song in songs where localURL(for: song.id) == nil && !pendingSongIDs.contains(song.id) {
            pending.append(Request(song: song, format: settings.format))
            pendingSongIDs.insert(song.id)
        }
        startNext()
    }

    public func updateSettings(_ value: DownloadSettings) {
        guard isReady, !isDeleting else { return }
        guard value.maximumBytes > 0, value.maximumBytes >= storage.usedBytes else {
            errorMessage = DownloadError.limitBelowUsage.localizedDescription
            return
        }
        do {
            try save(value, to: "settings.json")
            let policyChanged = settings.allowsCellular != value.allowsCellular || settings.maximumBytes != value.maximumBytes
            settings = value
            if !value.isEnabled {
                pending.removeAll()
                pendingSongIDs.removeAll()
                worker?.cancel()
            }
            if policyChanged { worker?.cancel() }
            startNext()
        } catch {
            errorMessage = "Couldn’t save download settings: \(error.localizedDescription)"
        }
    }

    public func refreshStorage() {
        storage = DownloadStorage(
            usedBytes: completed.reduce(0) { $0 + $1.byteCount },
            freeBytes: try? freeSpace(directory),
            songCount: completed.count,
            albumCount: Set(completed.compactMap { entry in
                entry.song.albumID ?? entry.song.album.map { "\(entry.song.artist ?? "")/\($0)" }
            }).count,
            artistCount: Set(completed.compactMap { $0.song.artistID ?? $0.song.artist }).count
        )
    }

    /// Cancels pending work and deletes only this account's offline files, never server music.
    public func deleteAll() async {
        guard !isDeleting else { return }
        isDeleting = true
        pending.removeAll()
        pendingSongIDs.removeAll()
        worker?.cancel()
        await worker?.value
        defer { isDeleting = false }
        do {
            for download in completed {
                let url = directory.appending(path: download.filename)
                if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
            }
            completed.removeAll()
            try save(completed, to: "manifest.json")
        } catch {
            completed.removeAll { !FileManager.default.fileExists(atPath: directory.appending(path: $0.filename).path) }
            errorMessage = "Couldn’t delete all downloads: \(error.localizedDescription)"
        }
        refreshStorage()
    }

    public func shutDown() async {
        isReady = false
        monitor?.cancel()
        pending.removeAll()
        pendingSongIDs.removeAll()
        worker?.cancel()
        await worker?.value
    }

    func updateNetwork(isConnected: Bool, isCellular: Bool) {
        self.isConnected = isConnected
        self.isCellular = isCellular
        if !canTransfer { worker?.cancel() }
        startNext()
    }

    func waitUntilIdle() async {
        while let worker { await worker.value }
    }

    private var canTransfer: Bool {
        settings.isEnabled && isConnected && (settings.allowsCellular || !isCellular)
    }

    private func startNext() {
        isWaitingForNetwork = !pending.isEmpty && !canTransfer && settings.isEnabled
        guard isReady, !isDeleting, worker == nil, canTransfer, let request = pending.first else { return }
        worker = Task { [weak self] in await self?.download(request) }
    }

    private func download(_ request: Request) async {
        let filename = UUID().uuidString + "." + Self.fileExtension(for: request)
        let temporary = directory.appending(path: "pending-" + filename)
        defer {
            try? FileManager.default.removeItem(at: temporary)
            worker = nil
            startNext()
        }
        do {
            let free = try freeSpace(directory)
            let budget = min(settings.maximumBytes - storage.usedBytes, max(0, free - Self.diskReserve))
            guard budget > 0 else { throw DownloadError.insufficientSpace }
            if request.format == .original, let size = request.song.size, size > budget {
                throw DownloadError.insufficientSpace
            }
            try await transfer(sourceURL(request.song.id, request.format), temporary, budget, settings.allowsCellular, request.format)
            try Task.checkCancellation()
            let bytes = Int64(try temporary.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0)
            guard bytes > 0 else { throw DownloadError.invalidAudio(request.format) }
            guard bytes <= settings.maximumBytes - storage.usedBytes else { throw DownloadError.insufficientSpace }
            guard try freeSpace(directory) >= Self.diskReserve else { throw DownloadError.insufficientSpace }
            let entry = DownloadedSong(song: request.song, format: request.format, filename: filename, byteCount: bytes)
            let updated = completed.filter { $0.id != entry.id } + [entry]
            let destination = directory.appending(path: filename)
            try FileManager.default.moveItem(at: temporary, to: destination)
            do {
                try save(updated, to: "manifest.json")
            } catch {
                try? FileManager.default.removeItem(at: destination)
                throw error
            }
            completed = updated
            finish(request)
            refreshStorage()
        } catch {
            guard !Task.isCancelled else { return }
            errorMessage = "\(request.song.title): \(error.localizedDescription)"
            finish(request)
            refreshStorage()
        }
    }

    private func finish(_ request: Request) {
        pending.removeAll { $0.song.id == request.song.id }
        pendingSongIDs.remove(request.song.id)
    }

    private func restore() {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            var location = directory
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try location.setResourceValues(values)
            let settingsURL = directory.appending(path: "settings.json")
            if FileManager.default.fileExists(atPath: settingsURL.path) {
                settings = try JSONDecoder().decode(DownloadSettings.self, from: Data(contentsOf: settingsURL))
            }
            let manifestURL = directory.appending(path: "manifest.json")
            if FileManager.default.fileExists(atPath: manifestURL.path) {
                completed = try JSONDecoder().decode([DownloadedSong].self, from: Data(contentsOf: manifestURL))
            }
            completed = try completed.filter { entry in
                guard entry.filename == URL(filePath: entry.filename).lastPathComponent else { return false }
                let url = directory.appending(path: entry.filename)
                guard FileManager.default.fileExists(atPath: url.path) else { return false }
                return Int64(try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) == entry.byteCount
            }
            let retained = Set(completed.map(\.filename) + ["settings.json", "manifest.json"])
            for url in try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) where !retained.contains(url.lastPathComponent) {
                try FileManager.default.removeItem(at: url)
            }
            try save(completed, to: "manifest.json")
            isReady = true
        } catch {
            errorMessage = "Couldn’t restore downloads: \(error.localizedDescription)"
        }
        refreshStorage()
    }

    private func save<Value: Encodable>(_ value: Value, to filename: String) throws {
        try JSONEncoder().encode(value).write(to: directory.appending(path: filename), options: .atomic)
    }

    private static let diskReserve: Int64 = 16_000_000

    private static func fileExtension(for request: Request) -> String {
        guard request.format == .original else { return request.format == .opus ? "ogg" : "mp3" }
        let suffix = request.song.suffix ?? "audio"
        return suffix.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber) } && !suffix.isEmpty ? suffix : "audio"
    }

    static func directory(for config: ServerConfig) -> URL {
        let identity = config.baseURL.absoluteString + "\n" + config.username
        let account = SHA256.hash(data: Data(identity.utf8)).map { String(format: "%02x", $0) }.joined()
        return URL.applicationSupportDirectory.appending(path: "Plinket/Downloads/\(account)")
    }

    nonisolated private static func availableSpace(at url: URL) throws -> Int64 {
        var volume = url
        volume.removeAllCachedResourceValues()
        let values = try volume.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        if let available = values.volumeAvailableCapacityForImportantUsage { return available }
        let attributes = try FileManager.default.attributesOfFileSystem(forPath: url.path)
        return (attributes[.systemFreeSize] as? NSNumber)?.int64Value ?? 0
    }
}
