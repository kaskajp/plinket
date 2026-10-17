import Foundation
import Subsonic

/// A model carrying its own star date.
protocol Starrable: Identifiable where ID == String {
    var starred: Date? { get set }
}

extension Album: Starrable {}
extension Song: Starrable {}
extension Artist: Starrable {}

extension Starrable {
    func settingStarred(_ date: Date?, ifID id: String) -> Self {
        guard self.id == id else { return self }
        var copy = self
        copy.starred = date
        return copy
    }
}

extension Array where Element: Starrable {
    func settingStarred(_ date: Date?, id: String) -> [Element] {
        map { $0.settingStarred(date, ifID: id) }
    }

    /// The favorites list with `item` at the front when starred, or without it when not.
    func favorites(updating item: Element, starredAt date: Date?) -> [Element] {
        let others = filter { $0.id != item.id }
        guard let date else { return others }
        var starredItem = item
        starredItem.starred = date
        return [starredItem] + others
    }

    func starDate(id: String) -> Date? {
        first { $0.id == id }?.starred
    }
}

extension Starred {
    var targets: Set<StarTarget> {
        Set(songs.map { .song($0.id) } + albums.map { .album($0.id) } + artists.map { .artist($0.id) })
    }
}
