import ReleaseNotes
import Testing

struct ChangelogTests {
    @Test func includesUnpublishedBuildNotesBeforeReleaseHistory() {
        let changelog = Changelog(markdown: """
        # Changelog
        Instructions for maintainers.

        ## [Unreleased]
        ### Added
        - **Offline** notes for the build being tested.
          Available before a public release.

        ## [1.1.0 (2)] - 2026-11-14
        A versioned TestFlight build.

        ### Fixed
        - First fix.
        - Second fix with a [link](https://example.com).

        ## [1.0.0 (1)] - 2026-10-19
        First version,
        across two lines.

        A second paragraph.

        [Unreleased]: https://example.com/compare
        [1.1.0 (2)]: https://example.com/release
        """)

        #expect(changelog.releases.map(\.version) == ["Unreleased", "1.1.0 (2)", "1.0.0 (1)"])
        #expect(changelog.releases[0].isUnreleased)
        #expect(changelog.releases[0].blocks == [
            .heading("Added"),
            .bullet("**Offline** notes for the build being tested. Available before a public release."),
        ])
        #expect(changelog.releases[1].date == "2026-11-14")
        #expect(changelog.releases[1].blocks == [
            .paragraph("A versioned TestFlight build."), .heading("Fixed"),
            .bullet("First fix."), .bullet("Second fix with a [link](https://example.com)."),
        ])
        #expect(changelog.releases[2].blocks == [
            .paragraph("First version, across two lines."), .paragraph("A second paragraph."),
        ])
    }

    @Test func omitsEmptyUnreleasedSectionAfterNotesAreFiled() {
        let changelog = Changelog(markdown: """
        # Changelog

        ## [Unreleased]

        ## [1.2.0 (3)] - 2026-11-15
        ### Added
        - New playback controls.

        [Unreleased]: https://example.com/compare
        """)

        #expect(changelog.releases.map(\.version) == ["1.2.0 (3)"])
        #expect(changelog.releases.first?.isUnreleased == false)
    }

    @Test func emptyDocumentHasNoReleaseNotes() {
        #expect(Changelog(markdown: "").releases.isEmpty)
    }
}
