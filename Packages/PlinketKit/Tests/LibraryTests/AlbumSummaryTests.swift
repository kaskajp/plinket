import Library
import Subsonic
import Testing

struct AlbumSummaryTests {
    @Test func summary_usesAlbumMetadataBeforeTracksLoad() {
        let album = Album(id: "album", name: "Album", songCount: 12, duration: 2880)

        let summary = AlbumSummary(album: album)

        #expect(summary.songCount == 12)
        #expect(summary.duration == 2880)
    }

    @Test func summary_prefersDetailMetadataOverListingAndIncompleteTracks() {
        let album = Album(id: "album", name: "Album", songCount: 10, duration: 2400)
        let detail = AlbumDetail(
            album: Album(id: "album", name: "Album", songCount: 12, duration: 2880),
            songs: [Song(id: "1", title: "One")]
        )

        let summary = AlbumSummary(album: album, detail: detail)

        #expect(summary.songCount == 12)
        #expect(summary.duration == 2880)
    }

    @Test func summary_keepsListingMetadataWhenDetailOmitsIt() {
        let album = Album(id: "album", name: "Album", songCount: 12, duration: 2880)
        let detail = AlbumDetail(album: Album(id: "album", name: "Album"), songs: [])

        let summary = AlbumSummary(album: album, detail: detail)

        #expect(summary.songCount == 12)
        #expect(summary.duration == 2880)
    }

    @Test func summary_totalsLoadedTracksAcrossDiscs() {
        let album = Album(id: "album", name: "Double")
        let detail = AlbumDetail(album: album, songs: [
            Song(id: "1", title: "One", discNumber: 1, duration: 120),
            Song(id: "2", title: "Two", discNumber: 2, duration: 180),
        ])

        let summary = AlbumSummary(album: album, detail: detail)

        #expect(summary.songCount == 2)
        #expect(summary.duration == 300)
    }

    @Test(arguments: [nil, 0, -1] as [Int?])
    func summary_omitsDurationWhenAnyTrackDurationIsUnknown(duration: Int?) {
        let album = Album(id: "album", name: "Album")
        let detail = AlbumDetail(album: album, songs: [
            Song(id: "1", title: "One", duration: 120),
            Song(id: "2", title: "Two", duration: duration),
        ])

        let summary = AlbumSummary(album: album, detail: detail)

        #expect(summary.songCount == 2)
        #expect(summary.duration == nil)
    }

    @Test func summary_omitsDurationWhenTracksDoNotMatchKnownCount() {
        let album = Album(id: "album", name: "Album", songCount: 12)
        let detail = AlbumDetail(album: Album(id: "album", name: "Album"), songs: [
            Song(id: "1", title: "One", duration: 120),
        ])

        let summary = AlbumSummary(album: album, detail: detail)

        #expect(summary.songCount == 12)
        #expect(summary.duration == nil)
    }

    @Test(arguments: [nil, 0, -1] as [Int?])
    func summary_omitsUnknownMetadataAndEmptyTrackTotals(value: Int?) {
        let album = Album(id: "album", name: "Album", songCount: value, duration: value)

        let summary = AlbumSummary(album: album, detail: AlbumDetail(album: album, songs: []))

        #expect(summary.songCount == nil)
        #expect(summary.duration == nil)
    }

    @Test func summary_usesTracksWhenMetadataIsZero() {
        let album = Album(id: "album", name: "Single", songCount: 0, duration: 0)
        let detail = AlbumDetail(album: album, songs: [Song(id: "1", title: "One", duration: 180)])

        let summary = AlbumSummary(album: album, detail: detail)

        #expect(summary.songCount == 1)
        #expect(summary.duration == 180)
    }

    @Test func summary_showsDurationWithoutCount() {
        let album = Album(id: "album", name: "Album", duration: 2880)

        let summary = AlbumSummary(album: album)

        #expect(summary.songCount == nil)
        #expect(summary.duration == 2880)
    }
}
