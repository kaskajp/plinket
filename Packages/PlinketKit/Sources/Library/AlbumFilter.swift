import Foundation
import Subsonic

/// Combined constraints for the Albums view; an empty filter matches every album.
public struct AlbumFilter: Sendable, Equatable {
    public var genre: String?
    public var mood: String?
    public var favoritesOnly: Bool
    public var minimumRating: Int?

    public var isActive: Bool {
        genre != nil || mood != nil || favoritesOnly || minimumRating != nil
    }

    public init(genre: String? = nil, mood: String? = nil, favoritesOnly: Bool = false, minimumRating: Int? = nil) {
        self.genre = genre
        self.mood = mood
        self.favoritesOnly = favoritesOnly
        self.minimumRating = minimumRating
    }

    public func matches(_ album: Album, isFavorite: Bool) -> Bool {
        if favoritesOnly && !isFavorite { return false }
        if let minimumRating, (album.userRating ?? 0) < minimumRating { return false }
        if let genre, !album.filterGenres.contains(where: { Self.sameTag($0, genre) }) { return false }
        if let mood, !(album.moods ?? []).contains(where: { Self.sameTag($0, mood) }) { return false }
        return true
    }

    public static func genres(in albums: [Album]) -> [String] {
        tagOptions(albums.flatMap(\.filterGenres))
    }

    public static func moods(in albums: [Album]) -> [String] {
        tagOptions(albums.flatMap { $0.moods ?? [] })
    }

    private static func sameTag(_ lhs: String, _ rhs: String) -> Bool {
        lhs.trimmingCharacters(in: .whitespacesAndNewlines)
            .caseInsensitiveCompare(rhs.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame
    }

    private static func tagOptions(_ tags: [String]) -> [String] {
        let names = tags.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        var seen: Set<String> = []
        return names.filter { seen.insert($0.lowercased()).inserted }
    }
}

private extension Album {
    var filterGenres: [String] {
        (genres ?? []).map(\.name) + (genre.map { [$0] } ?? [])
    }
}
