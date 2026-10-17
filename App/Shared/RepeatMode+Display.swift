import Playback
import SwiftUI

extension RepeatMode {
    /// The mode a repeat button switches to: off, all, one, then off again.
    var next: RepeatMode {
        switch self {
        case .off: .all
        case .all: .one
        case .one: .off
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .off: "Repeat Off"
        case .all: "Repeat All"
        case .one: "Repeat One"
        }
    }

    var systemImage: String {
        self == .one ? "repeat.1" : "repeat"
    }
}
