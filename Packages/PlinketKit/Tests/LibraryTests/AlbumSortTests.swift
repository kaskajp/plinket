import Foundation
import Library
import Subsonic
import Testing

struct AlbumSortTests {
    @Test func recentlyAdded_putsNewestFirstAndUndatedLast() {
        let albums = [
            Album(id: "undated", name: "Undated"),
            Album(id: "old", name: "Old", created: Date(timeIntervalSince1970: 100)),
            Album(id: "new", name: "New", created: Date(timeIntervalSince1970: 200)),
        ]

        let sorted = AlbumSort.recentlyAdded.sorted(albums)

        #expect(sorted.map(\.id) == ["new", "old", "undated"])
    }

    @Test func title_prefersServerSortName() {
        let albums = [
            Album(id: "the-wall", name: "The Wall", sortName: "wall"),
            Album(id: "abbey-road", name: "Abbey Road"),
        ]

        let sorted = AlbumSort.title.sorted(albums)

        #expect(sorted.map(\.id) == ["abbey-road", "the-wall"])
    }

    @Test func artist_ordersEachArtistsAlbumsByYear() {
        let albums = [
            Album(id: "b-2001", name: "Later", artist: "Band", year: 2001),
            Album(id: "a-1990", name: "Only", artist: "Artist", year: 1990),
            Album(id: "b-1999", name: "Earlier", artist: "Band", year: 1999),
        ]

        let sorted = AlbumSort.artist.sorted(albums)

        #expect(sorted.map(\.id) == ["a-1990", "b-1999", "b-2001"])
    }

    @Test func year_putsNewestFirst() {
        let albums = [
            Album(id: "1990", name: "A", year: 1990),
            Album(id: "2020", name: "B", year: 2020),
        ]

        let sorted = AlbumSort.year.sorted(albums)

        #expect(sorted.map(\.id) == ["2020", "1990"])
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
