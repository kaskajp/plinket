import ReleaseNotes
import SwiftUI

/// Reads the changelog shipped with this build, including unpublished notes.
struct ChangelogView: View {
    private static let changelog = Result {
        guard let url = Bundle.main.url(forResource: "CHANGELOG", withExtension: "md") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return Changelog(markdown: try String(contentsOf: url, encoding: .utf8))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(AppInfo.versionDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                switch Self.changelog {
                case .success(let changelog) where !changelog.releases.isEmpty:
                    ForEach(Array(changelog.releases.enumerated()), id: \.offset) { _, release in
                        releaseNotes(release)
                    }
                case .success:
                    ContentUnavailableView("No Release Notes", systemImage: "sparkles")
                case .failure:
                    ContentUnavailableView("Release Notes Unavailable", systemImage: "doc.text", description: Text("The changelog could not be read."))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .textSelection(.enabled)
        .navigationTitle("What’s New")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func releaseNotes(_ release: Changelog.Release) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(release.isUnreleased ? String(localized: "In This Build") : release.version)
                .font(.title2.bold())
                .accessibilityAddTraits(.isHeader)
            if !release.date.isEmpty {
                Text(release.date)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            ForEach(Array(release.blocks.enumerated()), id: \.offset) { _, block in
                switch block {
                case .heading(let text):
                    Text(LocalizedStringKey(text))
                        .font(.headline)
                        .padding(.top, 4)
                        .accessibilityAddTraits(.isHeader)
                case .paragraph(let text):
                    Text(LocalizedStringKey(text))
                case .bullet(let text):
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("•").accessibilityHidden(true)
                        Text(LocalizedStringKey(text))
                    }
                }
            }
            Divider().padding(.top, 8)
        }
    }
}
