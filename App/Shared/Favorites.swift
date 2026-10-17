import Library
import Subsonic
import SwiftUI

/// Adds the item to favorites, or removes it when it already is one.
struct FavoriteButton: View {
    let isFavorite: Bool
    let toggle: () -> Void

    var body: some View {
        Button(
            isFavorite ? "Remove from Favorites" : "Add to Favorites",
            systemImage: isFavorite ? "star.fill" : "star",
            action: toggle
        )
        .contentTransition(.symbolEffect(.replace))
    }
}

extension LibraryStore {
    func toggleFavorite(_ song: Song) {
        let isFavorite = isStarred(song)
        Task { await setStarred(!isFavorite, song: song) }
    }

    func toggleFavorite(_ album: Album) {
        let isFavorite = isStarred(album)
        Task { await setStarred(!isFavorite, album: album) }
    }

    func toggleFavorite(_ artist: Artist) {
        let isFavorite = isStarred(artist)
        Task { await setStarred(!isFavorite, artist: artist) }
    }
}

extension View {
    /// Tells the user when the server refused a favorite change; the store has rolled it back by then.
    func favoriteErrorAlert(library: LibraryStore) -> some View {
        alert(
            "Couldn’t Update Favorites",
            isPresented: Binding(get: { library.starError != nil }, set: { _ in library.dismissStarError() }),
            presenting: library.starError
        ) { _ in
            Button("OK") {}
        } message: { error in
            Text(error.localizedDescription)
        }
    }
}
