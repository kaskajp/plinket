import Foundation
import Subsonic

/// How the album grid is ordered. Sorting happens locally so switching is instant.
public enum AlbumSort: String, CaseIterable, Codable, Sendable {
    case recentlyAdded
    case title
    case artist
    case year

    public func sorted(_ albums: [Album]) -> [Album] {
        albums.sorted { comparison($0, $1) == .orderedAscending }
    }

    /// Oldest first, the way a discography reads; undated albums last.
    public static func chronological(_ albums: [Album]) -> [Album] {
        albums.sorted { lhs, rhs in
            compareNilsLast(lhs.year, rhs.year, descending: false).then(compareTitles(lhs, rhs)) == .orderedAscending
        }
    }

    private func comparison(_ lhs: Album, _ rhs: Album) -> ComparisonResult {
        let byTitle = Self.compareTitles(lhs, rhs)
        switch self {
        case .recentlyAdded:
            return Self.compareNilsLast(lhs.created, rhs.created, descending: true).then(byTitle)
        case .title:
            return byTitle
        case .artist:
            return Self.compareNilsLast(lhs.artist, rhs.artist, by: Self.compareText)
                .then(Self.compareNilsLast(lhs.year, rhs.year, descending: false))
                .then(byTitle)
        case .year:
            return Self.compareNilsLast(lhs.year, rhs.year, descending: true).then(byTitle)
        }
    }

    private static func compareTitles(_ lhs: Album, _ rhs: Album) -> ComparisonResult {
        compareText(lhs.sortName ?? lhs.name, rhs.sortName ?? rhs.name)
    }

    private static func compareText(_ lhs: String, _ rhs: String) -> ComparisonResult {
        lhs.localizedStandardCompare(rhs)
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
