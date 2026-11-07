import AppKit
import SwiftUI

/// Adds the app's description and project and support links to the standard About panel.
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
            string: AppInfo.summary + "\n\n" + AppInfo.affiliationDisclaimer + "\n",
            attributes: [.font: font, .foregroundColor: NSColor.labelColor, .paragraphStyle: paragraph]
        )
        let links = [
            (String(localized: "Visit Website"), AppInfo.websiteURL),
            (String(localized: "Privacy Policy"), AppInfo.privacyPolicyURL),
            (String(localized: "Report a Problem"), AppInfo.reportProblemURL),
            (String(localized: "What’s New"), AppInfo.changelogURL),
        ]
        for (index, (title, url)) in links.enumerated() {
            if index > 0 {
                let separator = index.isMultiple(of: 2) ? "\n" : "  ·  "
                credits.append(NSAttributedString(string: separator, attributes: [.font: font, .foregroundColor: NSColor.secondaryLabelColor, .paragraphStyle: paragraph]))
            }
            credits.append(NSAttributedString(string: title, attributes: [.font: font, .link: url, .paragraphStyle: paragraph]))
        }
        return credits
    }
}
