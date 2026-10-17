import Playback
import Subsonic
import SwiftUI

/// What browsing views ask of the player. Inactive until playback is installed at the root.
struct PlaybackActions: Sendable {
    var play: @MainActor @Sendable (_ songs: [Song], _ startIndex: Int) -> Void
    var shuffle: @MainActor @Sendable (_ songs: [Song]) -> Void
    var playNext: @MainActor @Sendable (_ songs: [Song]) -> Void
    var addToQueue: @MainActor @Sendable (_ songs: [Song]) -> Void

    static let inactive = PlaybackActions(play: { _, _ in }, shuffle: { _ in }, playNext: { _ in }, addToQueue: { _ in })
}

extension PlaybackActions {
    init(player: PlayerController) {
        self.init(
            play: { player.play(songs: $0, startingAt: $1) },
            shuffle: { player.shuffle(songs: $0) },
            playNext: { player.playNext($0) },
            addToQueue: { player.addToQueue($0) }
        )
    }
}

extension EnvironmentValues {
    @Entry var playbackActions = PlaybackActions.inactive
}
