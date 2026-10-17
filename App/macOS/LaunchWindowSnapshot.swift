#if DEBUG
import AppKit
import OSLog
import SwiftUI

extension View {
    /// Saves the window as `PLINKET_DEBUG_WINDOW_SNAPSHOT` (a PNG file name in the app's temporary directory)
    /// once launch has settled; capturing it from outside the app needs the screen recording permission.
    func writesLaunchWindowSnapshot() -> some View {
        modifier(LaunchWindowSnapshot())
    }
}

private struct LaunchWindowSnapshot: ViewModifier {
    private static let settleTime = Duration.seconds(8)

    func body(content: Content) -> some View {
        content.task {
            guard let fileName = ProcessInfo.processInfo.environment["PLINKET_DEBUG_WINDOW_SNAPSHOT"] else { return }
            do {
                try await Task.sleep(for: Self.settleTime)
            } catch {
                return
            }
            Self.writeSnapshot(named: fileName)
        }
    }

    private static func writeSnapshot(named fileName: String) {
        guard let frameView = NSApp.windows.first(where: \.isVisible)?.contentView?.superview,
              let bitmap = frameView.bitmapImageRepForCachingDisplay(in: frameView.bounds)
        else { return }
        frameView.cacheDisplay(in: frameView.bounds, to: bitmap)
        let fileURL = URL.temporaryDirectory.appending(path: fileName)
        do {
            try bitmap.representation(using: .png, properties: [:])?.write(to: fileURL)
            Logger.app.info("Wrote window snapshot to \(fileURL.path(percentEncoded: false))")
        } catch {
            Logger.app.error("Could not write window snapshot: \(error)")
        }
    }
}
#endif
