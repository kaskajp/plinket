import CarPlay
import Playback

/// Sets up the shared Now Playing template for one player: shuffle and repeat buttons, and the queue as Up Next.
@MainActor
final class CarPlayNowPlaying: NSObject, @MainActor CPNowPlayingTemplateObserver {
    private let player: PlayerController
    private let interfaceController: CPInterfaceController
    private let artwork: CarPlayArtwork

    init(player: PlayerController, interfaceController: CPInterfaceController, artwork: CarPlayArtwork) {
        self.player = player
        self.interfaceController = interfaceController
        self.artwork = artwork
        super.init()
        let template = CPNowPlayingTemplate.shared
        template.updateNowPlayingButtons([
            CPNowPlayingShuffleButton { _ in player.toggleShuffle() },
            CPNowPlayingRepeatButton { _ in player.setRepeat(player.repeatMode.next) },
        ])
        template.upNextTitle = String(localized: "Up Next")
        template.isUpNextButtonEnabled = true
        template.add(self)
    }

    func invalidate() {
        let template = CPNowPlayingTemplate.shared
        template.remove(self)
        template.updateNowPlayingButtons([])
        template.isUpNextButtonEnabled = false
    }

    /// Pushes Now Playing, or goes back to it when it is already on the stack.
    func show() {
        let template = CPNowPlayingTemplate.shared
        guard interfaceController.topTemplate !== template else { return }
        guard interfaceController.templates.contains(template) else {
            interfaceController.pushTemplate(template, animated: true, completion: nil)
            return
        }
        interfaceController.pop(to: template, animated: true, completion: nil)
    }

    func nowPlayingTemplateUpNextButtonTapped(_ nowPlayingTemplate: CPNowPlayingTemplate) {
        interfaceController.pushTemplate(upNextList().template, animated: true, completion: nil)
    }

    /// The current song and what follows it, as far as the car's list allows.
    private func upNextList() -> CarPlayList {
        let list = CarPlayList(title: String(localized: "Up Next"), artwork: artwork)
        list.setEmptyState(title: String(localized: "Nothing Queued"), message: nil, isLoading: false)
        let entries = player.entries
        guard let currentIndex = player.currentIndex else { return list }
        let shownIndices = entries.indices[currentIndex...].prefix(CarPlayLimits.itemCount)
        let items = shownIndices.map { index in
            CarPlayItems.song(entries[index].item, isPlaying: index == currentIndex) { [weak self] in
                self?.jump(to: index)
            }
        }
        let artworkRequests = zip(items, shownIndices).compactMap { item, index in
            CarPlayArtwork.Request(item: item, coverArtID: entries[index].item.coverArtID)
        }
        list.show([CPListSection(items: items)], artwork: artworkRequests)
        return list
    }

    private func jump(to index: Int) {
        player.jump(to: index)
        interfaceController.popTemplate(animated: true, completion: nil)
    }
}
