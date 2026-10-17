import Library
import Playback
import SwiftUI

struct LibraryRootView: View {
    @Environment(PlayerController.self) private var player
    @Environment(LibraryStore.self) private var library
    @State private var selection: LibrarySection? = Self.initialSelection
    @State private var searchQuery = LaunchOptions.searchQuery
    @State private var isShowingQueue = false

    var body: some View {
        NavigationSplitView {
            List(LibrarySection.sidebarSections, selection: $selection) { section in
                Label(section.title, systemImage: section.systemImage)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } detail: {
            detail
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        RefreshButton(collection: refreshableCollection)
                    }
                }
        }
        .searchable(text: $searchQuery, placement: .sidebar, prompt: "Artists, Albums, Songs")
        .onChange(of: selection) {
            searchQuery = ""
        }
        .focusedSceneValue(\.refreshableCollection, refreshableCollection)
        .inspector(isPresented: $isShowingQueue) {
            QueueView()
                .inspectorColumnWidth(min: 260, ideal: 300, max: 420)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            PlayerBar(isShowingQueue: $isShowingQueue)
        }
        .spaceBarTogglesPlayback(player.togglePlayPause)
        .commandArrowsMoveCursorWhileEditingText()
        #if DEBUG
        .writesLaunchWindowSnapshot()
        #endif
    }

    private static var initialSelection: LibrarySection {
        let section = LaunchOptions.initialSection
        return LibrarySection.sidebarSections.contains(section) ? section : .albums
    }

    private var isSearching: Bool {
        !searchQuery.isEmpty
    }

    private var refreshableCollection: LibraryCollection? {
        isSearching ? nil : (selection ?? .albums).collection
    }

    @ViewBuilder
    private var detail: some View {
        if isSearching {
            NavigationStack {
                SearchResultsView(query: searchQuery)
                    .navigationTitle("Search")
                    .libraryDestinations()
            }
        } else {
            let section = selection ?? .albums
            SectionNavigationStack(section: section) {
                LibrarySectionView(section: section)
            }
            .id(section)
        }
    }
}

/// Refreshes the visible section.
private struct RefreshButton: View {
    let collection: LibraryCollection?

    @Environment(LibraryStore.self) private var library

    var body: some View {
        Button("Refresh", systemImage: "arrow.clockwise") {
            guard let collection else { return }
            Task { await library.refresh(collection) }
        }
        .disabled(isUnavailable)
        .help("Refresh")
    }

    private var isUnavailable: Bool {
        guard let collection else { return true }
        return library.isRefreshing(collection)
    }
}
