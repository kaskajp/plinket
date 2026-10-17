import Playback
import SwiftUI

struct LibraryRootView: View {
    @Environment(PlayerController.self) private var player
    @State private var selectedSection = LaunchOptions.initialSection
    @State private var isShowingSettings = false
    @State private var isShowingNowPlaying = LaunchOptions.opensNowPlaying

    var body: some View {
        TabView(selection: $selectedSection) {
            Tab(LibrarySection.albums.title, systemImage: LibrarySection.albums.systemImage, value: .albums) {
                SectionNavigationStack(section: .albums) {
                    LibrarySectionView(section: .albums)
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button("Settings", systemImage: "gearshape") {
                                    isShowingSettings = true
                                }
                            }
                        }
                }
            }
            sectionTab(.artists)
            sectionTab(.playlists)
            sectionTab(.favorites)
            Tab(value: LibrarySection.search, role: .search) {
                SectionNavigationStack(section: .search) {
                    LibrarySectionView(section: .search)
                }
            }
        }
        .tabViewBottomAccessory(isEnabled: player.currentSong != nil) {
            if let song = player.currentSong {
                MiniPlayer(
                    song: song,
                    isPlaying: player.isPlaying,
                    open: { isShowingNowPlaying = true },
                    togglePlayPause: player.togglePlayPause,
                    next: player.next
                )
            }
        }
        .sheet(isPresented: $isShowingNowPlaying) {
            NowPlayingView()
        }
        .sheet(isPresented: $isShowingSettings) {
            NavigationStack {
                SettingsView()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { isShowingSettings = false }
                        }
                    }
            }
        }
    }

    private func sectionTab(_ section: LibrarySection) -> some TabContent<LibrarySection> {
        Tab(section.title, systemImage: section.systemImage, value: section) {
            SectionNavigationStack(section: section) {
                LibrarySectionView(section: section)
            }
        }
    }
}
