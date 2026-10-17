import Playback
import Subsonic
import SwiftUI

/// The current song and what plays after it; up-next songs can be reordered, removed or jumped to.
struct QueueView: View {
    @Environment(PlayerController.self) private var player

    var body: some View {
        if let currentIndex = player.currentIndex {
            QueueList(
                entries: player.entries,
                currentIndex: currentIndex,
                jump: player.jump(to:),
                move: player.move(fromOffsets:toOffset:),
                remove: player.remove(atOffsets:)
            )
        } else {
            ContentUnavailableView("Queue Is Empty", systemImage: "music.note.list")
        }
    }
}

private struct QueueList: View {
    let entries: [PlayQueue<Song>.Entry]
    let currentIndex: Int
    let jump: (Int) -> Void
    let move: (IndexSet, Int) -> Void
    let remove: (IndexSet) -> Void

    var body: some View {
        List {
            Section("Now Playing") {
                SongRow(song: entries[currentIndex].item)
            }
            Section("Up Next") {
                ForEach(Array(upNextEntries.enumerated()), id: \.element.id) { offset, entry in
                    Button {
                        jump(firstUpNextIndex + offset)
                    } label: {
                        SongRow(song: entry.item)
                    }
                    .buttonStyle(.plain)
                }
                .onMove { offsets, destination in
                    move(queueOffsets(offsets), firstUpNextIndex + destination)
                }
                .onDelete { offsets in
                    remove(queueOffsets(offsets))
                }
            }
        }
    }

    private var firstUpNextIndex: Int { currentIndex + 1 }

    private var upNextEntries: ArraySlice<PlayQueue<Song>.Entry> { entries[firstUpNextIndex...] }

    /// Up Next offsets count from the entry after the current one.
    private func queueOffsets(_ upNextOffsets: IndexSet) -> IndexSet {
        IndexSet(upNextOffsets.map { $0 + firstUpNextIndex })
    }
}
