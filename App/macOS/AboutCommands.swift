import AppKit
import SwiftUI

/// Replaces About Plinket so the standard panel also shows what the app is and links to its GitHub page.
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
        credits.append(NSAttributedString(
            string: String(localized: "Plinket on GitHub"),
            attributes: [.font: font, .link: AppInfo.repositoryURL, .paragraphStyle: paragraph]
        ))
        return credits
    }
}
