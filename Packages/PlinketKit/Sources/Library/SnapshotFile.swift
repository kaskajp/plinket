import Foundation
import OSLog

/// A list as last fetched from the server, persisted so launch can render before the network answers.
struct SnapshotFile<Snapshot: Codable & Sendable>: Sendable {
    let url: URL

    init(directory: URL, name: String) {
        url = directory.appending(path: "\(name).json")
    }

    @concurrent
    func load() async -> Snapshot? {
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else { return nil }
        do {
            return try JSONDecoder().decode(Snapshot.self, from: Data(contentsOf: url))
        } catch {
            Logger.library.error("Discarding unreadable snapshot \(url.lastPathComponent): \(error)")
            return nil
        }
    }

    @concurrent
    func save(_ snapshot: Snapshot) async {
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(snapshot).write(to: url, options: .atomic)
        } catch {
            Logger.library.error("Could not write snapshot \(url.lastPathComponent): \(error)")
        }
    }

    @concurrent
    func remove() async {
        do {
            try FileManager.default.removeItem(at: url)
        } catch CocoaError.fileNoSuchFile {
            return
        } catch {
            Logger.library.error("Could not remove snapshot \(url.lastPathComponent): \(error)")
        }
    }
}

extension Logger {
    static let library = Logger(subsystem: "nu.4z.plinket", category: "Library")
}
