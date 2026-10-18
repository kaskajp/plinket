import Foundation
import SwiftUI

/// What the About screens say about the app.
enum AppInfo {
    static let summary = String(localized: "A bare-essentials music player for your Navidrome library, made for intentional, album-first listening.")
    static let repositoryURL = URL(string: "https://github.com/kaskajp/plinket")!
    static let privacyPolicyURL = URL(string: "https://plinket.4z.nu/privacy/")!

    /// "Version 0.1.0 (1)", from the bundle.
    static var versionDescription: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return String(localized: "Version \(version) (\(build))")
    }
}

/// The app icon with the system's rounded corners, for screens inside the app.
struct AppLogo: View {
    let size: CGFloat

    var body: some View {
        Image("Logo")
            .resizable()
            .frame(width: size, height: size)
            .clipShape(.rect(cornerRadius: size * 0.225, style: .continuous))
            .shadow(color: .black.opacity(0.2), radius: size / 8, y: size / 16)
            .accessibilityHidden(true)
    }
}
