import AppKit
import SwiftUI

extension View {
    /// Lets ⌘← and ⌘→ move the cursor in a text field instead of triggering the Previous and Next menu items.
    func commandArrowsMoveCursorWhileEditingText() -> some View {
        modifier(CommandArrowsWhileEditing())
    }
}

/// Menu key equivalents are matched before the focused text view sees a key, so while text is being edited
/// this hands ⌘-arrow presses straight to the text view, which runs its usual line-navigation commands.
private struct CommandArrowsWhileEditing: ViewModifier {
    private static let arrowKeyCodes: Set<UInt16> = [123, 124]
    /// Arrow keys always carry these, so they say nothing about what the user is holding.
    private static let arrowKeyFlags: NSEvent.ModifierFlags = [.numericPad, .function]

    @State private var monitor: Any?

    func body(content: Content) -> some View {
        content
            .onAppear(perform: installMonitor)
            .onDisappear(perform: removeMonitor)
    }

    private func installMonitor() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard Self.isCommandArrow(event), let textView = event.window?.firstResponder as? NSText else { return event }
            textView.interpretKeyEvents([event])
            return nil
        }
    }

    private func removeMonitor() {
        guard let monitor else { return }
        NSEvent.removeMonitor(monitor)
        self.monitor = nil
    }

    private static func isCommandArrow(_ event: NSEvent) -> Bool {
        let heldModifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask).subtracting(arrowKeyFlags)
        return heldModifiers == .command && arrowKeyCodes.contains(event.keyCode)
    }
}
