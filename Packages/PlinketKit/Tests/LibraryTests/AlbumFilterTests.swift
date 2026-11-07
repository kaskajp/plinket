import Foundation
import Library
import Subsonic
import Testing

struct AlbumFilterTests {
    @Test func matches_combinesAllConstraints() {
        let filter = AlbumFilter(genre: "Jazz", mood: "Calm", favoritesOnly: true, minimumRating: 4)
        let matching = Album(id: "match", name: "Match", userRating: 4,
                             genres: [AlbumGenre(name: "Jazz")], moods: ["Calm"])
        let wrongGenre = Album(id: "genre", name: "Genre", genre: "Rock", userRating: 5, moods: ["Calm"])
        let wrongMood = Album(id: "mood", name: "Mood", genre: "Jazz", userRating: 5, moods: ["Energetic"])
        let lowRating = Album(id: "rating", name: "Rating", genre: "Jazz", userRating: 3, moods: ["Calm"])

        #expect(filter.matches(matching, isFavorite: true))
        #expect(!filter.matches(matching, isFavorite: false))
        #expect(!filter.matches(wrongGenre, isFavorite: true))
        #expect(!filter.matches(wrongMood, isFavorite: true))
        #expect(!filter.matches(lowRating, isFavorite: true))
    }

    @Test func genre_matchesLegacyAndSecondaryGenresIgnoringCaseAndWhitespace() {
        let filter = AlbumFilter(genre: "jazz")
        let legacy = Album(id: "legacy", name: "Legacy", genre: " Jazz ")
        let multiple = Album(id: "multi", name: "Multi", genre: "Rock",
                             genres: [AlbumGenre(name: "Rock"), AlbumGenre(name: "JAZZ")])

        #expect(filter.matches(legacy, isFavorite: false))
        #expect(filter.matches(multiple, isFavorite: false))
        #expect(!filter.matches(Album(id: "missing", name: "Missing"), isFavorite: false))
    }

    @Test func mood_matchesAnyMoodIgnoringCaseAndWhitespace() {
        let filter = AlbumFilter(mood: "calm")

        #expect(filter.matches(Album(id: "1", name: "Tagged", moods: ["Slow", " Calm "]), isFavorite: false))
        #expect(!filter.matches(Album(id: "2", name: "Untagged"), isFavorite: false))
    }

    @Test func minimumRating_excludesMissingAndZeroRatings() {
        let filter = AlbumFilter(minimumRating: 1)

        #expect(!filter.matches(Album(id: "nil", name: "Missing"), isFavorite: false))
        #expect(!filter.matches(Album(id: "zero", name: "Zero", userRating: 0), isFavorite: false))
        #expect(filter.matches(Album(id: "rated", name: "Rated", userRating: 1), isFavorite: false))
    }

    @Test func clear_matchesAlbumsWithoutOptionalMetadata() {
        var filter = AlbumFilter(genre: "Jazz", mood: "Calm", favoritesOnly: true, minimumRating: 5)
        #expect(filter.isActive)

        filter = AlbumFilter()

        #expect(!filter.isActive)
        #expect(filter.matches(Album(id: "1", name: "Bare"), isFavorite: false))
    }

    @Test func options_mergeMetadataAndRemoveBlankAndDuplicateTags() {
        let albums = [
            Album(id: "1", name: "One", genre: " Jazz ", genres: [AlbumGenre(name: "Electronic")],
                  moods: [" Slow ", "Calm", ""]),
            Album(id: "2", name: "Two", genre: "jazz", genres: [AlbumGenre(name: " ")],
                  moods: ["slow", " "]),
            Album(id: "3", name: "Three"),
        ]

        #expect(AlbumFilter.genres(in: albums).map { $0.lowercased() } == ["electronic", "jazz"])
        #expect(AlbumFilter.moods(in: albums).map { $0.lowercased() } == ["calm", "slow"])
    }
}
