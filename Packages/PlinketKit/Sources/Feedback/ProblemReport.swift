import Foundation

/// A user-submitted report; it deliberately contains no music server or account details.
public struct ProblemReport: Codable, Sendable {
    public static let maximumScreenshots = 3
    public static let maximumScreenshotBytes = 2 * 1024 * 1024
    public static let maximumTitleLength = 200
    public static let maximumDetailsLength = 10_000

    public let id: UUID
    public let title: String
    public let details: String
    public let appVersion: String
    public let platform: String
    public let osVersion: String
    public let locale: String
    public let screenshots: [Data]

    public init(id: UUID, title: String, details: String, appVersion: String, platform: String,
                osVersion: String, locale: String, screenshots: [Data]) {
        self.id = id
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.details = details.trimmingCharacters(in: .whitespacesAndNewlines)
        self.appVersion = appVersion
        self.platform = platform
        self.osVersion = osVersion
        self.locale = locale
        self.screenshots = screenshots
    }

    public var isValid: Bool {
        !title.isEmpty && title.unicodeScalars.count <= Self.maximumTitleLength
            && !details.isEmpty && details.unicodeScalars.count <= Self.maximumDetailsLength
            && screenshots.count <= Self.maximumScreenshots
            && screenshots.allSatisfy { !$0.isEmpty && $0.count <= Self.maximumScreenshotBytes }
    }
}
