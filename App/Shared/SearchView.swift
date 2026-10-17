import Library
import Subsonic
import SwiftUI

/// The search field and its results, for platforms where search is its own section.
struct SearchView: View {
    @State private var query = LaunchOptions.searchQuery

    var body: some View {
        SearchResultsView(query: query)
            .navigationTitle("Search")
            .searchable(text: $query, prompt: "Artists, Albums, Songs")
    }
}

/// Artists, albums and songs matching `query`, searched once typing pauses.
struct SearchResultsView: View {
    private static let typingPause = Duration.milliseconds(300)

    let query: String

    @Environment(LibraryStore.self) private var library
    @State private var result: SearchResult?
    @State private var searchError: SubsonicError?

    var body: some View {
        content
            .task(id: query) { await search() }
    }

    @ViewBuilder
    private var content: some View {
        if query.trimmingCharacters(in: .whitespaces).isEmpty {
            ContentUnavailableView("Search Your Library", systemImage: "magnifyingglass", description: Text("Find artists, albums and songs."))
        } else if let searchError {
            ContentUnavailableView("Couldn’t Search", systemImage: "exclamationmark.triangle", description: Text(searchError.localizedDescription))
        } else if let result {
            if result.isEmpty {
                ContentUnavailableView.search(text: query)
            } else {
                SearchResultsList(result: result)
            }
        } else {
            ProgressView()
        }
    }

    /// `task(id:)` cancels the previous search whenever `query` changes, which also ends its pause early.
    private func search() async {
        do {
            try await Task.sleep(for: Self.typingPause)
        } catch {
            return
        }
        do {
            result = try await library.search(query)
            searchError = nil
        } catch {
            guard !Task.isCancelled else { return }
            searchError = error
        }
    }
}

private struct SearchResultsList: View {
    let result: SearchResult

    var body: some View {
        List {
            if !result.artists.isEmpty {
                Section("Artists") {
                    ForEach(result.artists) { artist in
                        NavigationLink(value: artist) {
                            ArtistRow(artist: artist)
                        }
                    }
                }
            }
            if !result.albums.isEmpty {
                Section("Albums") {
                    ForEach(result.albums) { album in
                        NavigationLink(value: album) {
                            AlbumListRow(album: album)
                        }
                    }
                }
            }
            if !result.songs.isEmpty {
                Section("Songs") {
                    ForEach(result.songs) { song in
                        PlayableSong(songs: [song], index: 0) {
                            SongRow(song: song)
                        }
                    }
                }
            }
        }
    }
}

private struct AlbumListRow: View {
    private static let artworkSize: CGFloat = 40

    let album: Album

    var body: some View {
        HStack(spacing: 12) {
            CoverArtImage(coverArtID: album.coverArtID, pointSize: Self.artworkSize, cornerRadius: 4)
                .frame(width: Self.artworkSize, height: Self.artworkSize)
            VStack(alignment: .leading, spacing: 2) {
                Text(album.name)
                    .lineLimit(1)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }

    private var subtitle: String? {
        let parts = [album.artist, album.yearText].compactMap(\.self)
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

private extension SearchResult {
    var isEmpty: Bool {
        artists.isEmpty && albums.isEmpty && songs.isEmpty
    }
}
