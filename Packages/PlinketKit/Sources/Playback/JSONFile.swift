import Foundation
import OSLog

/// Where playback state that should survive relaunches is kept.
public enum PlaybackStorage {
    public static let defaultDirectory = URL.applicationSupportDirectory.appending(path: "Plinket")
}

/// A value persisted as JSON in one file. Being an actor keeps writes in order and off the main thread.
actor JSONFile<Value: Codable & Sendable> {
    let url: URL

    init(url: URL) {
        self.url = url
    }

    func load() -> Value? {
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else { return nil }
        do {
            return try JSONDecoder().decode(Value.self, from: Data(contentsOf: url))
        } catch {
            Logger.playback.error("Discarding unreadable \(self.url.lastPathComponent): \(error)")
            return nil
        }
    }

    func save(_ value: Value) {
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(value).write(to: url, options: .atomic)
        } catch {
            Logger.playback.error("Could not write \(self.url.lastPathComponent): \(error)")
        }
    }

    func remove() {
        do {
            try FileManager.default.removeItem(at: url)
        } catch CocoaError.fileNoSuchFile {
            return
        } catch {
            Logger.playback.error("Could not remove \(self.url.lastPathComponent): \(error)")
        }
    }
}
