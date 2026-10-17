import CarPlay
import Subsonic

/// List items for library models. Selecting one runs its action while CarPlay shows a spinner on the item.
@MainActor
enum CarPlayItems {
    typealias Action = @MainActor () async -> Void

    static func album(_ album: Album, open: @escaping Action) -> CPListItem {
        let item = CPListItem(text: album.name, detailText: album.artist, image: nil, accessoryImage: nil, accessoryType: .disclosureIndicator)
        setAction(of: item, to: open)
        return item
    }

    static func playlist(_ playlist: Playlist, open: @escaping Action) -> CPListItem {
        let item = CPListItem(
            text: playlist.name,
            detailText: songCountAndDuration(songCount: playlist.songCount, duration: playlist.duration),
            image: nil,
            accessoryImage: nil,
            accessoryType: .disclosureIndicator
        )
        setAction(of: item, to: open)
        return item
    }

    static func song(_ song: Song, isPlaying: Bool = false, play: @escaping Action) -> CPListItem {
        let item = CPListItem(text: song.title, detailText: song.artist)
        item.isPlaying = isPlaying
        setAction(of: item, to: play)
        return item
    }

    static func command(_ title: String, systemImage: String, perform: @escaping Action) -> CPListItem {
        let item = CPListItem(text: title, detailText: nil, image: UIImage(systemName: systemImage))
        setAction(of: item, to: perform)
        return item
    }

    private static func setAction(of item: CPListItem, to action: @escaping Action) {
        item.handler = { _, completion in
            Task {
                await action()
                completion()
            }
        }
    }
}
