import AppKit
import SwiftUI

extension View {
    /// Toggles playback on Space unless a text field or text view is being edited.
    func spaceBarTogglesPlayback(_ togglePlayPause: @escaping @MainActor () -> Void) -> some View {
        modifier(SpaceBarPlayPause(togglePlayPause: togglePlayPause))
    }
}

/// A plain-Space menu shortcut would swallow spaces typed into search fields, so this watches key events
/// instead and steps aside whenever text editing has focus.
private struct SpaceBarPlayPause: ViewModifier {
    private static let spaceKeyCode: UInt16 = 49

    let togglePlayPause: @MainActor () -> Void

    @State private var monitor: Any?

    func body(content: Content) -> some View {
        content
            .onAppear(perform: installMonitor)
            .onDisappear(perform: removeMonitor)
    }

    private func installMonitor() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard Self.isPlainSpace(event), !Self.isEditingText(in: event.window) else { return event }
            togglePlayPause()
            return nil
        }
    }

    private func removeMonitor() {
        guard let monitor else { return }
        NSEvent.removeMonitor(monitor)
        self.monitor = nil
    }

    private static func isPlainSpace(_ event: NSEvent) -> Bool {
        event.keyCode == spaceKeyCode && event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty
    }

    private static func isEditingText(in window: NSWindow?) -> Bool {
        window?.firstResponder is NSText
    }
}
