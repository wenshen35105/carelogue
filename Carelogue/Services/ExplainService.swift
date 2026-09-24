import Foundation
import SwiftData

/// Parsed form of `Artifact.aiExplainJSON` (spec §4 / §5):
/// {summary_plain, terms[{original, plain}], questions[], model, created_at}.
nonisolated struct Explanation: Codable, Equatable {
    struct Term: Codable, Equatable, Hashable {
        var original: String
        var plain: String
    }

    var summaryPlain: String
    var terms: [Term]
    var questions: [String]
    var model: String?
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case summaryPlain = "summary_plain"
        case terms, questions, model
        case createdAt = "created_at"
    }

    /// Lenient decode of the model's reply: missing arrays become empty,
    /// blank entries are dropped. Only a missing / blank summary is invalid.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        summaryPlain = (try? container.decode(String.self, forKey: .summaryPlain))?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        terms = ((try? container.decode([Term].self, forKey: .terms)) ?? [])
            .filter { !$0.original.trimmingCharacters(in: .whitespaces).isEmpty }
        questions = ((try? container.decode([String].self, forKey: .questions)) ?? [])
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        model = try? container.decode(String.self, forKey: .model)
        createdAt = try? container.decode(Date.self, forKey: .createdAt)
    }

    init(summaryPlain: String, terms: [Term], questions: [String], model: String?, createdAt: Date?) {
        self.summaryPlain = summaryPlain
        self.terms = terms
        self.questions = questions
        self.model = model
        self.createdAt = createdAt
    }

    /// Plain-text version for the 复制 action.
    var plainText: String {
        var parts = [summaryPlain]
        if !terms.isEmpty {
            parts.append(terms.map { "· \($0.original)：\($0.plain)" }.joined(separator: "\n"))
        }
        if !questions.isEmpty {
            parts.append(String(localized: "可以问问医生：") + "\n"
                         + questions.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n"))
        }
        parts.append(String(localized: "AI 解释仅帮助理解报告，不能替代医生的诊断。"))
        return parts.joined(separator: "\n\n")
    }
}

extension Artifact {
    var explanation: Explanation? {
        guard let json = aiExplainJSON, let data = json.data(using: .utf8) else { return nil }
        return try? ExplainService.decoder.decode(Explanation.self, from: data)
    }
}

enum ExplainError: LocalizedError, Equatable {
    case aiDisabled
    case consentRequired
    case extraction(TextExtractionError)
    case service(AIServiceError)
    /// Blank / non-JSON / refused reply.
    case unusableReply

    var errorDescription: String? {
        switch self {
        case .aiDisabled: return String(localized: "AI 解释已在设置中关闭")
        case .consentRequired: return String(localized: "需要先同意 AI 解释说明")
        case .extraction(let error): return error.errorDescription
        case .service(let error): return error.errorDescription
        case .unusableReply: return String(localized: "这次没有得到可用的解释")
        }
    }
}

enum ExplainOutcome: Equatable {
    case fresh(Explanation)
    /// Returned from cache because the last explanation is under 5 minutes
    /// old (spec §5 cost control) — no request was sent.
    case throttled(Explanation)
}

/// `explainArtifact(artifact)` from spec §5: extract text on device, add
/// minimal context, ask the model with guard-rails, validate, cache.
enum ExplainService {
    static let throttleInterval: TimeInterval = 5 * 60
    /// Keeps prompts (and cost) bounded for very long PDFs.
    static let maxInputCharacters = 12_000

    /// Artifacts with a request in flight; a second tap is ignored.
    private static var inFlight: Set<UUID> = []

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    static func isExplaining(_ artifact: Artifact) -> Bool {
        inFlight.contains(artifact.id)
    }

    static func explain(_ artifact: Artifact, in context: ModelContext, now: Date = .now) async throws -> ExplainOutcome {
        guard AISettings.isEnabled else { throw ExplainError.aiDisabled }
        // Nothing leaves the device without consent — the UI asks first,
        // this is the backstop.
        guard AISettings.consent == .granted else { throw ExplainError.consentRequired }

        if let cached = artifact.explanation, let createdAt = cached.createdAt,
           now.timeIntervalSince(createdAt) < throttleInterval {
            return .throttled(cached)
        }
        guard !inFlight.contains(artifact.id) else { throw CancellationError() }
        inFlight.insert(artifact.id)
        defer { inFlight.remove(artifact.id) }

        // The signed transaction travels with the request; without one the
        // relay would refuse it anyway, so this fails fast and locally (T27).
        let entitlement = await SubscriptionService.shared.entitlementToken()
        let service: any AIService
        do {
            service = try AISettings.makeService(entitlement: entitlement)
        } catch let error as AIServiceError {
            throw ExplainError.service(error)
        }

        let text: String
        do {
            text = try await TextExtractor.extract(data: artifact.fileData, mime: artifact.mime)
        } catch let error as TextExtractionError {
            throw ExplainError.extraction(error)
        }

        let reply: String
        do {
            reply = try await service.run(AIRequest(
                action: AIRequest.explainReport,
                locale: AppLanguage.code,
                content: .init(reportText: String(text.prefix(maxInputCharacters))),
                context: requestContext(for: artifact, in: context)
            ))
        } catch let error as AIServiceError {
            throw ExplainError.service(error)
        }

        guard var explanation = parse(reply) else { throw ExplainError.unusableReply }
        explanation.model = service.modelName
        explanation.createdAt = now

        // Only a validated, non-empty result is cached (spec: 不缓存空结果).
        let data = try encoder.encode(explanation)
        artifact.aiExplainJSON = String(data: data, encoding: .utf8)
        artifact.log?.updatedAt = now
        try? context.save()
        return .fresh(explanation)
    }

    /// Accepts a bare JSON object or one wrapped in ```json fences.
    static func parse(_ reply: String) -> Explanation? {
        var body = reply.trimmingCharacters(in: .whitespacesAndNewlines)
        if let start = body.firstIndex(of: "{"), let end = body.lastIndex(of: "}"), start < end {
            body = String(body[start...end])
        }
        guard let data = body.data(using: .utf8),
              let explanation = try? decoder.decode(Explanation.self, from: data),
              !explanation.summaryPlain.isEmpty else { return nil }
        return explanation
    }

    /// Journey name + Profile allergies / medications (spec §5b), unless
    /// switched off in Settings. A field left nil is not encoded at all, so
    /// with the switch off the relay never receives it.
    private static func requestContext(for artifact: Artifact, in context: ModelContext) -> AIRequest.Context {
        var result = AIRequest.Context(journeyName: nonEmpty(artifact.log?.journey?.name))
        if AISettings.includesProfile, let profile = try? context.fetch(FetchDescriptor<Profile>()).first {
            result.allergies = nonEmpty(profile.allergies)
            result.medications = nonEmpty(profile.medications)
        }
        return result
    }

    private static func nonEmpty(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}
