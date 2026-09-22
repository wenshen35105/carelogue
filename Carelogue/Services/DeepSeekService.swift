import Foundation

/// DeepSeek chat/completions client (OpenAI-compatible API). The client talks
/// to DeepSeek directly over HTTPS — Carelogue has no server of its own.
struct DeepSeekService: AIService {
    let apiKey: String
    var modelName: String { "deepseek-chat" }

    private static let endpoint = URL(string: "https://api.deepseek.com/chat/completions")!

    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral // no cache / cookies on disk
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 90
        configuration.waitsForConnectivity = false
        return URLSession(configuration: configuration)
    }()

    private struct Message: Codable {
        let role: String
        let content: String
    }

    private struct RequestBody: Encodable {
        struct ResponseFormat: Encodable { let type: String }
        let model: String
        let messages: [Message]
        let temperature: Double
        let stream: Bool
        let response_format: ResponseFormat?
    }

    private struct ResponseBody: Decodable {
        struct Choice: Decodable { let message: Message }
        let choices: [Choice]
    }

    func complete(system: String, user: String, json: Bool) async throws -> String {
        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(RequestBody(
            model: modelName,
            messages: [Message(role: "system", content: system), Message(role: "user", content: user)],
            temperature: 0.3,
            stream: false,
            response_format: json ? .init(type: "json_object") : nil
        ))

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
        switch http.statusCode {
        case 200: break
        case 401, 403: throw AIServiceError.unauthorized
        case 402: throw AIServiceError.insufficientBalance
        case 429: throw AIServiceError.rateLimited
        default: throw AIServiceError.server(http.statusCode)
        }

        guard let body = try? JSONDecoder().decode(ResponseBody.self, from: data),
              let content = body.choices.first?.message.content,
              !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AIServiceError.invalidResponse
        }
        return content
    }
}
