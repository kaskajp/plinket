import Foundation
import Library
import Subsonic
import Testing

struct AlbumSortTests {
    @Test func recentlyPlayed_putsLatestPlaysFirstAndUnplayedLast() {
        let albums = [
            Album(id: "unplayed", name: "A"),
            Album(id: "older", name: "B", created: Date(timeIntervalSince1970: 300), played: Date(timeIntervalSince1970: 100)),
            Album(id: "latest", name: "C", created: Date(timeIntervalSince1970: 100), played: Date(timeIntervalSince1970: 200)),
        ]

        let sorted = AlbumSort.recentlyPlayed.sorted(albums)

        #expect(sorted.map(\.id) == ["latest", "older", "unplayed"])
    }

    @Test(arguments: AlbumSort.Direction.allCases)
    func recentlyPlayed_keepsUnplayedLastAndBreaksTiesByTitle(direction: AlbumSort.Direction) {
        let played = Date(timeIntervalSince1970: 100)
        let albums = [
            Album(id: "unplayed-z", name: "Z"),
            Album(id: "played-z", name: "Z", played: played),
            Album(id: "unplayed-a", name: "A"),
            Album(id: "played-a", name: "A", played: played),
            Album(id: "latest", name: "Latest", played: Date(timeIntervalSince1970: 200)),
        ]

        let sorted = AlbumSort.recentlyPlayed.sorted(albums, direction: direction)

        let playedIDs = direction == .ascending ? ["played-a", "played-z", "latest"] : ["latest", "played-a", "played-z"]
        #expect(sorted.map(\.id) == playedIDs + ["unplayed-a", "unplayed-z"])
    }

    @Test(arguments: AlbumSort.Direction.allCases)
    func recentlyAdded_keepsUndatedLast(direction: AlbumSort.Direction) {
        let albums = [
            Album(id: "undated", name: "Undated"),
            Album(id: "old", name: "Old", created: Date(timeIntervalSince1970: 100)),
            Album(id: "new", name: "New", created: Date(timeIntervalSince1970: 200)),
        ]

        let sorted = AlbumSort.recentlyAdded.sorted(albums, direction: direction)

        let dated = direction == .ascending ? ["old", "new"] : ["new", "old"]
        #expect(sorted.map(\.id) == dated + ["undated"])
    }

    @Test(arguments: AlbumSort.Direction.allCases)
    func title_prefersServerSortNameAndKeepsBlankTitlesLast(direction: AlbumSort.Direction) {
        let albums = [
            Album(id: "the-wall", name: "The Wall", sortName: "wall"),
            Album(id: "abbey-road", name: "Abbey Road"),
            Album(id: "blank", name: " \n "),
            Album(id: "fallback", name: "Middle", sortName: " "),
        ]

        let sorted = AlbumSort.title.sorted(albums, direction: direction)

        let titled = direction == .ascending
            ? ["abbey-road", "fallback", "the-wall"] : ["the-wall", "fallback", "abbey-road"]
        #expect(sorted.map(\.id) == titled + ["blank"])
    }

    @Test(arguments: AlbumSort.Direction.allCases)
    func artist_keepsDiscographiesChronologicalAndMissingArtistsLast(direction: AlbumSort.Direction) {
        let albums = [
            Album(id: "b-2001", name: "Later", artist: "Band", year: 2001),
            Album(id: "a-1990", name: "Only", artist: "Artist", year: 1990),
            Album(id: "b-1999", name: "Earlier", artist: "Band", year: 1999),
            Album(id: "b-undated", name: "Undated", artist: "Band"),
            Album(id: "missing", name: "A"),
            Album(id: "blank", name: "B", artist: " \n "),
        ]

        let sorted = AlbumSort.artist.sorted(albums, direction: direction)

        let withArtists = direction == .ascending
            ? ["a-1990", "b-1999", "b-2001", "b-undated"] : ["b-1999", "b-2001", "b-undated", "a-1990"]
        #expect(sorted.map(\.id) == withArtists + ["missing", "blank"])
    }

    @Test(arguments: AlbumSort.Direction.allCases)
    func year_keepsUndatedLastAndBreaksTiesByTitle(direction: AlbumSort.Direction) {
        let albums = [
            Album(id: "1990", name: "A", year: 1990),
            Album(id: "2020", name: "B", year: 2020),
            Album(id: "2020-a", name: "A", year: 2020),
            Album(id: "undated", name: "C"),
        ]

        let sorted = AlbumSort.year.sorted(albums, direction: direction)

        let dated = direction == .ascending ? ["1990", "2020-a", "2020"] : ["2020-a", "2020", "1990"]
        #expect(sorted.map(\.id) == dated + ["undated"])
    }

    @Test func chronological_putsOldestFirstAndUndatedLast() {
        let albums = [
            Album(id: "undated", name: "A"),
            Album(id: "2020", name: "B", year: 2020),
            Album(id: "1990", name: "C", year: 1990),
        ]

        let sorted = AlbumSort.chronological(albums)

        #expect(sorted.map(\.id) == ["1990", "2020", "undated"])
    }
}
