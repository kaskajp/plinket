import Library
import SwiftUI

extension FocusedValues {
    /// What the focused window's visible section refreshes; `nil` when it has nothing to refresh.
    @Entry var refreshableCollection: LibraryCollection?
}

/// View ▸ Refresh (⌘R), available at any depth of the section's navigation.
struct LibraryCommands: Commands {
    let library: LibraryStore?

    @FocusedValue(\.refreshableCollection) private var refreshableCollection

    var body: some Commands {
        CommandGroup(before: .toolbar) {
            Button("Refresh") {
                guard let library, let refreshableCollection else { return }
                Task { await library.refresh(refreshableCollection) }
            }
            .keyboardShortcut("r")
            .disabled(isUnavailable)
            Divider()
        }
    }

    private var isUnavailable: Bool {
        guard let library, let refreshableCollection else { return true }
        return library.isRefreshing(refreshableCollection)
    }
}
