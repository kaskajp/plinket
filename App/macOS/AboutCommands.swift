import AppKit
import SwiftUI

/// Replaces About Plinket so the standard panel also shows what the app is and links to its website and privacy policy.
struct AboutCommands: Commands {
    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("About Plinket") {
                NSApp.orderFrontStandardAboutPanel(options: [.credits: Self.credits])
            }
        }
    }

    private static var credits: NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.paragraphSpacing = 6
        let font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        let credits = NSMutableAttributedString(
            string: AppInfo.summary + "\n",
            attributes: [.font: font, .foregroundColor: NSColor.labelColor, .paragraphStyle: paragraph]
        )
        let links = [
            (String(localized: "Visit Website"), AppInfo.websiteURL),
            (String(localized: "Privacy Policy"), AppInfo.privacyPolicyURL),
        ]
        for (index, (title, url)) in links.enumerated() {
            if index > 0 {
                credits.append(NSAttributedString(string: "  ·  ", attributes: [.font: font, .foregroundColor: NSColor.secondaryLabelColor, .paragraphStyle: paragraph]))
            }
            credits.append(NSAttributedString(string: title, attributes: [.font: font, .link: url, .paragraphStyle: paragraph]))
        }
        return credits
    }
}
