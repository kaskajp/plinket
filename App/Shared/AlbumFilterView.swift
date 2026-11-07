import Library
import SwiftUI

/// Edits combined filters using metadata from the entire library.
struct AlbumFilterView: View {
    @Binding var filter: AlbumFilter
    let genres: [String]
    let moods: [String]
    let matchingCount: Int

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Genre", selection: $filter.genre) {
                        Text("All Genres").tag(String?.none)
                        ForEach(genreOptions, id: \.self) { genre in
                            Text(genre).tag(Optional(genre))
                        }
                    }
                    .disabled(genres.isEmpty && filter.genre == nil)
                    Picker("Mood", selection: $filter.mood) {
                        Text("All Moods").tag(String?.none)
                        ForEach(moodOptions, id: \.self) { mood in
                            Text(mood).tag(Optional(mood))
                        }
                    }
                    .disabled(moods.isEmpty && filter.mood == nil)
                } footer: {
                    if moods.isEmpty {
                        Text("No mood tags are available in this library.")
                    }
                }
                Section {
                    Toggle("Favorites Only", isOn: $filter.favoritesOnly)
                    Picker("Minimum Rating", selection: $filter.minimumRating) {
                        Text("Any Rating").tag(Int?.none)
                        ForEach(1...5, id: \.self) { rating in
                            Text(rating == 1 ? "1 Star & Up" : "\(rating) Stars & Up")
                                .tag(Optional(rating))
                        }
                    }
                } footer: {
                    Text("Matching Albums: \(matchingCount)")
                }
                Section {
                    Button("Clear Filters") { filter = AlbumFilter() }
                        .disabled(!filter.isActive)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Filter Albums")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
        #if os(macOS)
        .frame(minWidth: 380, minHeight: 360)
        #endif
    }

    private var genreOptions: [String] {
        includingSelection(filter.genre, in: genres)
    }

    private var moodOptions: [String] {
        includingSelection(filter.mood, in: moods)
    }

    private func includingSelection(_ selection: String?, in options: [String]) -> [String] {
        guard let selection, !options.contains(selection) else { return options }
        return [selection] + options
    }
}
