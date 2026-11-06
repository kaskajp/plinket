import Foundation
import Subsonic
import Synchronization
import Testing
@testable import Downloads

@MainActor
struct DownloadManagerTests {
    @Test func completedDownloadsAndSettingsSurviveRestart() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let manager = makeManager(directory: directory)
        manager.updateSettings(DownloadSettings(format: .mp3, allowsCellular: true, maximumBytes: 1_000))
        manager.updateNetwork(isConnected: true, isCellular: false)
        manager.enqueue([song("one"), song("two"), song("one")])
        await manager.waitUntilIdle()

        let restored = makeManager(directory: directory)

        #expect(restored.settings == manager.settings)
        #expect(restored.storage.usedBytes == 20)
        #expect(restored.storage.songCount == 2)
        #expect(restored.storage.albumCount == 1)
        #expect(restored.storage.artistCount == 1)
        let localURL = try #require(restored.localURL(for: "one"))
        #expect(try Data(contentsOf: localURL).count == 10)
        #expect(restored.completed.allSatisfy { $0.format == .mp3 })
    }

    @Test func disablingPreventsNewDownloadsButKeepsCompletedFiles() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let manager = makeManager(directory: directory)
        manager.updateNetwork(isConnected: true, isCellular: false)
        manager.enqueue([song("one")])
        await manager.waitUntilIdle()
        manager.updateSettings(DownloadSettings(isEnabled: false))

        manager.enqueue([song("two")])
        await manager.waitUntilIdle()

        #expect(manager.localURL(for: "one") != nil)
        #expect(manager.localURL(for: "two") == nil)
        #expect(manager.errorMessage?.contains("Enable downloads") == true)
    }

    @Test func disablingCancelsActiveAndQueuedDownloads() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let probe = TransferProbe()
        let manager = makeManager(directory: directory, transfer: { try await probe.transfer($0, $1, $2, $3, $4) })
        manager.updateNetwork(isConnected: true, isCellular: false)
        manager.enqueue([song("one"), song("two")])
        let active = await probe.nextCall()

        manager.updateSettings(DownloadSettings(isEnabled: false))
        await manager.waitUntilIdle()

        #expect(manager.completed.isEmpty)
        #expect(manager.pendingSongIDs.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: active.destination.path))
        #expect(!makeManager(directory: directory).settings.isEnabled)
    }

    @Test func revokingCellularPermissionCancelsAnActiveCellularTransfer() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let probe = TransferProbe()
        let manager = makeManager(directory: directory, transfer: { try await probe.transfer($0, $1, $2, $3, $4) })
        manager.updateSettings(DownloadSettings(allowsCellular: true))
        manager.updateNetwork(isConnected: true, isCellular: true)
        manager.enqueue([song("one")])
        let first = await probe.nextCall()
        #expect(first.allowsCellular)

        manager.updateSettings(DownloadSettings(allowsCellular: false))
        await manager.waitUntilIdle()

        #expect(manager.isWaitingForNetwork)
        #expect(manager.completed.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: first.destination.path))
        manager.updateNetwork(isConnected: true, isCellular: false)
        let resumed = await probe.nextCall()
        #expect(!resumed.allowsCellular)
        try await probe.finish()
        await manager.waitUntilIdle()
        #expect(manager.localURL(for: "one") != nil)
    }

    @Test func cellularChangeCancelsPartialFileAndResumesOnWiFi() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let probe = TransferProbe()
        let manager = makeManager(directory: directory, transfer: { try await probe.transfer($0, $1, $2, $3, $4) })
        manager.updateNetwork(isConnected: true, isCellular: false)
        manager.enqueue([song("one")])
        let first = await probe.nextCall()
        #expect(!first.allowsCellular)

        manager.updateNetwork(isConnected: true, isCellular: true)
        await manager.waitUntilIdle()

        #expect(manager.isWaitingForNetwork)
        #expect(manager.completed.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: first.destination.path))
        manager.updateNetwork(isConnected: true, isCellular: false)
        _ = await probe.nextCall()
        try await probe.finish()
        await manager.waitUntilIdle()
        #expect(manager.localURL(for: "one") != nil)
    }

    @Test func allowingCellularStartsWaitingDownloadAndUsesQueuedFormat() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let probe = TransferProbe()
        let manager = makeManager(directory: directory, transfer: { try await probe.transfer($0, $1, $2, $3, $4) })
        manager.updateNetwork(isConnected: true, isCellular: true)
        manager.updateSettings(DownloadSettings(format: .opus))
        manager.enqueue([song("one")])
        #expect(manager.isWaitingForNetwork)

        manager.updateSettings(DownloadSettings(format: .mp3, allowsCellular: true))
        let call = await probe.nextCall()
        try await probe.finish()
        await manager.waitUntilIdle()

        #expect(call.allowsCellular)
        #expect(call.format == .opus)
        #expect(manager.completed.first?.format == .opus)
    }

    @Test func storageLimitRejectsUnknownSizeOverflowWithoutPublishingFile() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let manager = makeManager(directory: directory)
        manager.updateSettings(DownloadSettings(maximumBytes: 15))
        manager.updateNetwork(isConnected: true, isCellular: false)
        manager.enqueue([song("one"), song("two")])
        await manager.waitUntilIdle()

        #expect(manager.storage.songCount == 1)
        #expect(manager.storage.usedBytes == 10)
        #expect(manager.localURL(for: "two") == nil)
        #expect(manager.errorMessage?.contains("Not enough space") == true)
        manager.updateSettings(DownloadSettings(maximumBytes: 5))
        #expect(manager.settings.maximumBytes == 15)
    }

    @Test func knownOriginalSizeOverBudgetIsRejectedBeforeTransfer() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let manager = makeManager(directory: directory, transfer: { _, _, _, _, _ in
            Issue.record("A known oversized original must not start transferring")
        })
        manager.updateSettings(DownloadSettings(maximumBytes: 15))
        manager.updateNetwork(isConnected: true, isCellular: false)

        manager.enqueue([Song(id: "large", title: "Large", size: 100)])
        await manager.waitUntilIdle()

        #expect(manager.storage.songCount == 0)
        #expect(manager.errorMessage?.contains("Not enough space") == true)
    }

    @Test func failedTransferCleansPartialFileAndExplainsUnavailableFormat() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let writtenFile = Mutex<URL?>(nil)
        let manager = makeManager(directory: directory, transfer: { _, destination, _, _, format in
            writtenFile.withLock { $0 = destination }
            try Data([1]).write(to: destination)
            throw DownloadError.invalidAudio(format)
        })
        manager.updateSettings(DownloadSettings(format: .opus))
        manager.updateNetwork(isConnected: true, isCellular: false)

        manager.enqueue([song("one")])
        await manager.waitUntilIdle()

        #expect(manager.completed.isEmpty)
        #expect(manager.pendingSongIDs.isEmpty)
        #expect(manager.errorMessage?.contains("playable Opus") == true)
        let partialFile = try #require(writtenFile.withLock { $0 })
        #expect(!FileManager.default.fileExists(atPath: partialFile.path))
        #expect(makeManager(directory: directory).storage.songCount == 0)
    }

    @Test func insufficientDeviceSpacePreventsTransfer() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let manager = makeManager(directory: directory, transfer: { _, _, _, _, _ in
            Issue.record("Insufficient device space must prevent transfer")
        }, freeSpace: { _ in 1 })
        manager.updateNetwork(isConnected: true, isCellular: false)
        manager.enqueue([song("one")])
        await manager.waitUntilIdle()

        #expect(manager.storage.songCount == 0)
        #expect(manager.errorMessage?.contains("Not enough space") == true)
    }

    @Test func deleteAllCancelsActiveWorkAndKeepsSettings() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let probe = TransferProbe()
        let manager = makeManager(directory: directory, transfer: { try await probe.transfer($0, $1, $2, $3, $4) })
        manager.updateNetwork(isConnected: true, isCellular: false)
        manager.enqueue([song("one"), song("two")])
        _ = await probe.nextCall()
        try await probe.finish()
        let active = await probe.nextCall()
        let completedFile = try #require(manager.localURL(for: "one"))

        await manager.deleteAll()

        #expect(manager.storage.usedBytes == 0)
        #expect(manager.storage.songCount == 0)
        #expect(manager.pendingSongIDs.isEmpty)
        #expect(manager.localURL(for: "one") == nil)
        #expect(!FileManager.default.fileExists(atPath: completedFile.path))
        let restored = makeManager(directory: directory)
        #expect(restored.completed.isEmpty)
        #expect(restored.settings == manager.settings)
        #expect(!FileManager.default.fileExists(atPath: active.destination.path))
    }

    @Test func shuttingDownKeepsCompletedDownloadsForTheNextSession() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let manager = makeManager(directory: directory)
        manager.updateNetwork(isConnected: true, isCellular: false)
        manager.enqueue([song("one")])
        await manager.waitUntilIdle()

        await manager.shutDown()
        manager.enqueue([song("two")])
        let restored = makeManager(directory: directory)

        #expect(restored.localURL(for: "one") != nil)
        #expect(restored.localURL(for: "two") == nil)
        #expect(manager.pendingSongIDs.isEmpty)
    }

    @Test func restoreRemovesInterruptedTransfersAndMissingFiles() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let manager = makeManager(directory: directory)
        manager.updateNetwork(isConnected: true, isCellular: false)
        manager.enqueue([song("one")])
        await manager.waitUntilIdle()
        try FileManager.default.removeItem(at: #require(manager.localURL(for: "one")))
        let partial = directory.appending(path: "pending-interrupted.mp3")
        try Data([0]).write(to: partial)

        let restored = makeManager(directory: directory)

        #expect(restored.storage.songCount == 0)
        #expect(!FileManager.default.fileExists(atPath: partial.path))
    }

    @Test func accountsAndServersUseSeparateStorage() throws {
        let first = try ServerConfig(serverAddress: "https://first.example", username: "one")
        let otherUser = try ServerConfig(serverAddress: "https://first.example", username: "two")
        let otherServer = try ServerConfig(serverAddress: "https://second.example", username: "one")
        #expect(DownloadManager.directory(for: first) != DownloadManager.directory(for: otherUser))
        #expect(DownloadManager.directory(for: first) != DownloadManager.directory(for: otherServer))
    }

    private func makeManager(
        directory: URL,
        transfer: @escaping DownloadManager.Transfer = { _, destination, _, _, _ in
            try Data(repeating: 1, count: 10).write(to: destination)
        },
        freeSpace: @escaping @Sendable (URL) throws -> Int64 = { _ in 1_000_000_000 }
    ) -> DownloadManager {
        DownloadManager(
            directory: directory,
            sourceURL: { _, _ in URL(string: "https://music.example/download")! },
            transfer: transfer,
            freeSpace: freeSpace
        )
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory.appending(path: "PlinketDownloadsTests-\(UUID())")
    }

    private func song(_ id: String) -> Song {
        Song(id: id, title: id, album: "Album", albumID: "album", artist: "Artist", artistID: "artist")
    }
}

private actor TransferProbe {
    struct Call: Sendable {
        let destination: URL
        let allowsCellular: Bool
        let format: DownloadFormat
    }

    private var calls: [Call] = []
    private var waiter: CheckedContinuation<Call, Never>?
    private var completion: CheckedContinuation<Void, any Error>?
    private var destination: URL?

    func transfer(_ source: URL, _ destination: URL, _ budget: Int64, _ allowsCellular: Bool, _ format: DownloadFormat) async throws {
        self.destination = destination
        try Data([1]).write(to: destination)
        try await withTaskCancellationHandler {
            try Task.checkCancellation()
            try await withCheckedThrowingContinuation { continuation in
                completion = continuation
                let call = Call(destination: destination, allowsCellular: allowsCellular, format: format)
                if let waiter {
                    self.waiter = nil
                    waiter.resume(returning: call)
                    return
                }
                calls.append(call)
            }
        } onCancel: {
            Task { await self.cancel() }
        }
    }

    func nextCall() async -> Call {
        if !calls.isEmpty { return calls.removeFirst() }
        return await withCheckedContinuation { waiter = $0 }
    }

    func finish() throws {
        if let destination { try Data(repeating: 1, count: 10).write(to: destination) }
        completion?.resume()
        completion = nil
    }

    private func cancel() {
        completion?.resume(throwing: CancellationError())
        completion = nil
    }
}
