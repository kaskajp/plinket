import Foundation

public enum FeedbackError: LocalizedError {
    case invalidReport
    case unavailable
    case rejected(Int)
    case invalidResponse

    public var errorDescription: String? {
        switch self {
        case .invalidReport: String(localized: "Enter a summary and description, and attach up to three screenshots.")
        case .unavailable: String(localized: "Problem reporting is not configured in this build.")
        case .rejected(429): String(localized: "Too many reports. Please wait a few minutes and try again.")
        case .rejected: String(localized: "Your report could not be sent. Please try again.")
        case .invalidResponse: String(localized: "The server did not confirm your report. Please try again.")
        }
    }
}

/// Sends reports to the developer's relay, without embedding a Linear credential.
public struct FeedbackClient: Sendable {
    private let endpoint: URL
    private let session: URLSession

    public init(endpoint: URL, session: URLSession = .shared) {
        self.endpoint = endpoint
        self.session = session
    }

    public func submit(_ report: ProblemReport) async throws {
        guard report.isValid else { throw FeedbackError.invalidReport }
        guard endpoint.scheme == "https", endpoint.host != nil else { throw FeedbackError.unavailable }
        var request = URLRequest(url: endpoint, timeoutInterval: 90)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(report)
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw FeedbackError.invalidResponse }
        guard response.statusCode == 201 else { throw FeedbackError.rejected(response.statusCode) }
        guard let receipt = try? JSONDecoder().decode(Receipt.self, from: data), receipt.id == report.id else {
            throw FeedbackError.invalidResponse
        }
    }

    private struct Receipt: Decodable {
        let id: UUID
    }
}
