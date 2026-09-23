import Foundation

/// Talks to Carelogue's own relay (server/, T26) instead of a model provider
/// directly: the device sends extracted report text plus the App Store
/// transaction that proves the subscription, and gets the model's reply back.
///
/// Same `AIService` shape as before, so everything above this layer — the
/// prompt, the guard rails, the explanation card — is unchanged (spec §11).
struct CarelogueServerService: AIService {
    /// Overridable so `wrangler dev` can be pointed at during development.
    static let baseURL: URL = {
        if let override = UserDefaults.standard.string(forKey: "ai.serverURL"),
           let url = URL(string: override) {
            return url
        }
        return URL(string: "https://api.carelogue.ca")!
    }()

    /// The relay names the model it used; until a reply arrives this is what
    /// Settings shows.
    static let serviceDisplayName = "Carelogue"

    let entitlementToken: String
    var modelName: String { lastModel ?? "carelogue-relay" }

    /// Set from the reply so the explanation records which model wrote it.
    private let lastModelBox = ModelBox()
    private var lastModel: String? { lastModelBox.value }

    init(entitlementToken: String) {
        self.entitlementToken = entitlementToken
    }

    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 90
        configuration.waitsForConnectivity = false
        return URLSession(configuration: configuration)
    }()

    private struct RequestBody: Encodable {
        let system: String
        let user: String
        let json: Bool
    }

    private struct ReplyBody: Decodable {
        let content: String
        let model: String?
    }

    private struct ErrorBody: Decodable {
        let error: String
    }

    func complete(system: String, user: String, json: Bool) async throws -> String {
        var request = URLRequest(url: Self.baseURL.appendingPathComponent("v1/explain"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(entitlementToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(RequestBody(system: system, user: user, json: json))

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await Self.session.data(for: request)
        } catch let error as URLError {
            switch error.code {
            case .timedOut: throw AIServiceError.timeout
            case .notConnectedToInternet, .networkConnectionLost, .cannotFindHost,
                 .cannotConnectToHost, .dataNotAllowed, .internationalRoamingOff:
                throw AIServiceError.offline
            default: throw AIServiceError.server(error.errorCode)
            }
        }

        guard let http = response as? HTTPURLResponse else { throw AIServiceError.invalidResponse }
        let code = (try? JSONDecoder().decode(ErrorBody.self, from: data))?.error

        switch http.statusCode {
        case 200: break
        case 401: throw AIServiceError.notSubscribed
        case 402: throw code == "expired" ? AIServiceError.subscriptionExpired : AIServiceError.notSubscribed
        case 413: throw AIServiceError.reportTooLong
        case 429: throw AIServiceError.rateLimited
        case 504: throw AIServiceError.timeout
        default: throw AIServiceError.server(http.statusCode)
        }

        guard let body = try? JSONDecoder().decode(ReplyBody.self, from: data),
              !body.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AIServiceError.invalidResponse
        }
        lastModelBox.value = body.model
        return body.content
    }
}

/// `AIService` is a value type, so the model name from the last reply needs a
/// reference to live in.
private final class ModelBox: @unchecked Sendable {
    var value: String?
}
