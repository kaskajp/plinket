import Library
import Subsonic
import Testing

struct ArtistIndexTests {
    @Test func sorted_filesBySortNameWithNonLettersLast() {
        let artists = [
            Artist(id: "2-mello", name: "2 Mello"),
            Artist(id: "the-beatles", name: "The Beatles", sortName: "beatles"),
            Artist(id: "abba", name: "ABBA"),
        ]

        let sorted = ArtistIndex.sorted(artists)

        #expect(sorted.map(\.id) == ["abba", "the-beatles", "2-mello"])
    }

    @Test func title_foldsDiacritics() {
        let artist = Artist(id: "emilie", name: "émilie")

        #expect(ArtistIndex.title(for: artist) == "E")
    }

    @Test func sections_groupsArtistsSharingALetter() {
        let artists = ArtistIndex.sorted([
            Artist(id: "abba", name: "ABBA"),
            Artist(id: "air", name: "Air"),
            Artist(id: "bjork", name: "Björk"),
        ])

        let sections = ArtistIndex.sections(ofSorted: artists)

        #expect(sections.map(\.title) == ["A", "B"] && sections[0].artists.count == 2)
    }
}
