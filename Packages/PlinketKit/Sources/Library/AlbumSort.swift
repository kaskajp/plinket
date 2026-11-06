import Foundation
import Subsonic

/// How the album grid is ordered. Sorting happens locally so switching is instant.
public enum AlbumSort: String, CaseIterable, Codable, Sendable {
    case recentlyAdded
    case recentlyPlayed
    case rating
    case title
    case artist
    case year

    public enum Direction: String, CaseIterable, Codable, Sendable {
        case ascending
        case descending
    }

    public var defaultDirection: Direction {
        switch self {
        case .title, .artist: .ascending
        case .recentlyAdded, .recentlyPlayed, .rating, .year: .descending
        }
    }

    public func sorted(_ albums: [Album]) -> [Album] {
        sorted(albums, direction: defaultDirection)
    }

    public func sorted(_ albums: [Album], direction: Direction) -> [Album] {
        albums.sorted { comparison($0, $1, direction: direction) == .orderedAscending }
    }

    /// Oldest first, the way a discography reads; undated albums last.
    public static func chronological(_ albums: [Album]) -> [Album] {
        albums.sorted { lhs, rhs in
            compareNilsLast(lhs.year, rhs.year, descending: false).then(compareTitles(lhs, rhs)) == .orderedAscending
        }
    }

    private func comparison(_ lhs: Album, _ rhs: Album, direction: Direction) -> ComparisonResult {
        switch self {
        case .recentlyAdded:
            return Self.compareNilsLast(lhs.created, rhs.created, descending: direction == .descending)
                .then(Self.compareTitles(lhs, rhs))
        case .recentlyPlayed:
            return Self.compareNilsLast(lhs.played, rhs.played, descending: direction == .descending)
                .then(Self.compareTitles(lhs, rhs))
        case .title:
            return Self.compareTitles(lhs, rhs, direction: direction)
        case .rating:
            return Self.compareNilsLast(Self.rating(lhs), Self.rating(rhs), descending: direction == .descending)
                .then(Self.compareTitles(lhs, rhs))
        case .artist:
            return Self.compareNilsLast(Self.sortText(lhs.artist), Self.sortText(rhs.artist)) {
                Self.compareText($0, $1, direction: direction)
            }
                .then(Self.compareNilsLast(lhs.year, rhs.year, descending: false))
                .then(Self.compareTitles(lhs, rhs))
        case .year:
            return Self.compareNilsLast(lhs.year, rhs.year, descending: direction == .descending)
                .then(Self.compareTitles(lhs, rhs))
        }
    }

    private static func rating(_ album: Album) -> Int? {
        guard let rating = album.userRating, rating > 0 else { return nil }
        return rating
    }

    private static func compareTitles(
        _ lhs: Album,
        _ rhs: Album,
        direction: Direction = .ascending
    ) -> ComparisonResult {
        compareNilsLast(sortText(lhs.sortName) ?? sortText(lhs.name), sortText(rhs.sortName) ?? sortText(rhs.name)) {
            compareText($0, $1, direction: direction)
        }
    }

    private static func sortText(_ text: String?) -> String? {
        guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        return text
    }

    private static func compareText(_ lhs: String, _ rhs: String, direction: Direction) -> ComparisonResult {
        let comparison = lhs.localizedStandardCompare(rhs)
        return direction == .descending ? comparison.reversed : comparison
    }

    private static func compareNilsLast<Value: Comparable>(
        _ lhs: Value?,
        _ rhs: Value?,
        descending: Bool
    ) -> ComparisonResult {
        compareNilsLast(lhs, rhs) { left, right in
            let ascending = compareValues(left, right)
            return descending ? ascending.reversed : ascending
        }
    }

    private static func compareValues<Value: Comparable>(_ lhs: Value, _ rhs: Value) -> ComparisonResult {
        if lhs < rhs {
            return .orderedAscending
        }
        if lhs > rhs {
            return .orderedDescending
        }
        return .orderedSame
    }

    private static func compareNilsLast<Value>(
        _ lhs: Value?,
        _ rhs: Value?,
        by compare: (Value, Value) -> ComparisonResult
    ) -> ComparisonResult {
        switch (lhs, rhs) {
        case let (left?, right?):
            compare(left, right)
        case (nil, nil):
            .orderedSame
        case (nil, _):
            .orderedDescending
        case (_, nil):
            .orderedAscending
        }
    }
}

private extension ComparisonResult {
    var reversed: ComparisonResult {
        switch self {
        case .orderedAscending: .orderedDescending
        case .orderedDescending: .orderedAscending
        case .orderedSame: .orderedSame
        }
    }

    func then(_ tieBreaker: @autoclosure () -> ComparisonResult) -> ComparisonResult {
        self == .orderedSame ? tieBreaker() : self
    }
}
