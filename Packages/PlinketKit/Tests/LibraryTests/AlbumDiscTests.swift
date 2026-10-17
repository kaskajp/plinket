import Library
import Subsonic
import Testing

struct AlbumDiscTests {
    @Test func discs_groupSongIndicesByDiscNumber() {
        let detail = AlbumDetail(album: Album(id: "al-1", name: "Double"), songs: [
            Song(id: "1", title: "One", discNumber: 1),
            Song(id: "2", title: "Two", discNumber: 2),
            Song(id: "3", title: "Three", discNumber: 2),
        ])

        #expect(detail.discs.map(\.songIndices) == [[0], [1, 2]])
    }

    @Test func discs_countSongsWithoutDiscNumberAsDiscOne() {
        let detail = AlbumDetail(album: Album(id: "al-1", name: "Single"), songs: [
            Song(id: "1", title: "One"),
            Song(id: "2", title: "Two", discNumber: 1),
        ])

        #expect(detail.discs.map(\.number) == [1])
    }
}
