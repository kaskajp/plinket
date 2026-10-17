import Foundation
import Subsonic

/// Artists filed under one letter of an A–Z index.
public struct ArtistIndexSection: Identifiable, Sendable, Hashable {
    public let title: String
    public let artists: [Artist]

    public var id: String { title }
}

/// Files artists under the first letter of their sort name, with everything else under "#" at the end.
public enum ArtistIndex {
    public static let nonLetterTitle = "#"

    public static func title(for artist: Artist) -> String {
        let folded = sortKey(artist).folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
        guard let initial = folded.first, initial.isLetter else { return nonLetterTitle }
        return String(initial).uppercased()
    }

    public static func sorted(_ artists: [Artist]) -> [Artist] {
        artists
            .map { (title: title(for: $0), artist: $0) }
            .sorted { lhs, rhs in
                guard lhs.title == rhs.title else { return precedes(lhs.title, rhs.title) }
                return sortKey(lhs.artist).localizedStandardCompare(sortKey(rhs.artist)) == .orderedAscending
            }
            .map(\.artist)
    }

    /// Groups artists already in ``sorted(_:)`` order.
    public static func sections(ofSorted artists: [Artist]) -> [ArtistIndexSection] {
        var sections: [ArtistIndexSection] = []
        var currentTitle: String?
        var currentArtists: [Artist] = []
        for artist in artists {
            let title = title(for: artist)
            if let currentTitle, currentTitle != title {
                sections.append(ArtistIndexSection(title: currentTitle, artists: currentArtists))
                currentArtists = []
            }
            currentTitle = title
            currentArtists.append(artist)
        }
        if let currentTitle {
            sections.append(ArtistIndexSection(title: currentTitle, artists: currentArtists))
        }
        return sections
    }

    private static func sortKey(_ artist: Artist) -> String {
        artist.sortName ?? artist.name
    }

    private static func precedes(_ lhs: String, _ rhs: String) -> Bool {
        if lhs == nonLetterTitle {
            return false
        }
        if rhs == nonLetterTitle {
            return true
        }
        return lhs.localizedStandardCompare(rhs) == .orderedAscending
    }
}
