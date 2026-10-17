import CarPlay

/// A list template whose content is replaced as a whole, with cover art filled in afterwards.
@MainActor
final class CarPlayList {
    let template: CPListTemplate
    private let artwork: CarPlayArtwork
    private var artworkLoad: Task<Void, Never>?

    init(title: String, artwork: CarPlayArtwork) {
        template = CPListTemplate(title: title, sections: [])
        self.artwork = artwork
    }

    /// Callers trim their items to ``CarPlayLimits/itemCount``, so no more items are made than CarPlay shows.
    func show(_ sections: [CPListSection], artwork requests: [CarPlayArtwork.Request]) {
        artworkLoad?.cancel()
        template.updateSections(Array(sections.filter { !$0.items.isEmpty }.prefix(CarPlayLimits.sectionCount)))
        artworkLoad = artwork.loadImages(requests)
    }

    /// What the list says while it has no items.
    func setEmptyState(title: String, message: String?, isLoading: Bool) {
        template.emptyViewTitleVariants = [title]
        template.emptyViewSubtitleVariants = message.map { [$0] } ?? []
        template.showsSpinnerWhileEmpty = isLoading
    }
}

/// The car's limits on list length, which vary between cars.
@MainActor
enum CarPlayLimits {
    static var itemCount: Int { Int(CPListTemplate.maximumItemCount) }
    static var sectionCount: Int { Int(CPListTemplate.maximumSectionCount) }
}
