import Foundation
import SwiftData

/// What the doctor said, as stored on the visit (T32). Mirrors the relay's
/// `summarize_visit` reply: {said_plain, key_points[], follow_ups[]}.
nonisolated struct VisitSummary: Codable, Equatable {
    var saidPlain: String
    var keyPoints: [String]
    var followUps: [String]
    var model: String?
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case saidPlain = "said_plain"
        case keyPoints = "key_points"
        case followUps = "follow_ups"
        case model
        case createdAt = "created_at"
    }

    /// Lenient like `Explanation`: missing lists become empty, blanks are
    /// dropped, and only a missing summary makes the reply unusable.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        saidPlain = (try? container.decode(String.self, forKey: .saidPlain))?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        keyPoints = Self.cleaned(try? container.decode([String].self, forKey: .keyPoints))
        followUps = Self.cleaned(try? container.decode([String].self, forKey: .followUps))
        model = try? container.decode(String.self, forKey: .model)
        createdAt = try? container.decode(Date.self, forKey: .createdAt)
    }

    init(saidPlain: String, keyPoints: [String], followUps: [String], model: String? = nil, createdAt: Date? = nil) {
        self.saidPlain = saidPlain
        self.keyPoints = keyPoints
        self.followUps = followUps
        self.model = model
        self.createdAt = createdAt
    }

    private static func cleaned(_ list: [String]?) -> [String] {
        (list ?? []).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    /// Plain text for 复制要点.
    var plainText: String {
        var parts = [saidPlain]
        if !keyPoints.isEmpty {
            parts.append(String(localized: "关键要点：") + "\n"
                         + keyPoints.map { "· \($0)" }.joined(separator: "\n"))
        }
        if !followUps.isEmpty {
            parts.append(String(localized: "可以再问：") + "\n"
                         + followUps.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n"))
        }
        parts.append(String(localized: "AI 整理，可能有遗漏；请以医生原话与病历为准"))
        return parts.joined(separator: "\n\n")
    }
}

/// 我的疑问: what the patient wants to ask, and the English the doctor reads.
nonisolated struct VisitQuestions: Codable, Equatable {
    struct Item: Codable, Equatable, Identifiable {
        var id: UUID = UUID()
        var text: String
        /// Nil until translated; a question is usable without it.
        var translated: String?
    }

    var items: [Item] = []
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case items
        case updatedAt = "updated_at"
    }

    var needsTranslation: Bool {
        items.contains { ($0.translated ?? "").isEmpty }
    }
}

extension Log {
    var visitSummary: VisitSummary? {
        guard let json = visitSummaryJSON, let data = json.data(using: .utf8) else { return nil }
        return try? ExplainService.decoder.decode(VisitSummary.self, from: data)
    }

    var visitQuestions: VisitQuestions {
        guard let json = questionsJSON, let data = json.data(using: .utf8),
              let decoded = try? ExplainService.decoder.decode(VisitQuestions.self, from: data) else {
            return VisitQuestions()
        }
        return decoded
    }

    /// The visit's recording, if it has one. Audio is the only attachment kind
    /// that is not shown in the 附件 list — it has a card of its own.
    var recording: Artifact? {
        allArtifacts.first { $0.mime.hasPrefix("audio/") }
    }

    var fileAttachments: [Artifact] {
        allArtifacts.filter { !$0.mime.hasPrefix("audio/") }
    }
}

extension Artifact {
    static let audioMime = "audio/m4a"
    var isRecording: Bool { mime.hasPrefix("audio/") }
}

enum VisitError: LocalizedError, Equatable {
    case aiDisabled
    case consentRequired
    case noTranscript
    case service(AIServiceError)
    case unusableReply

    var errorDescription: String? {
        switch self {
        case .aiDisabled: return String(localized: "AI 整理已在设置中关闭")
        case .consentRequired: return String(localized: "需要先同意 AI 说明")
        case .noTranscript: return String(localized: "这段录音还没有转写出文字")
        case .service(let error): return error.errorDescription
        case .unusableReply: return String(localized: "这次没有整理出可用的结果")
        }
    }
}

/// The two AI jobs the visit recording adds (T32). Both take text that was
/// produced on the device and send only that text — the audio never leaves.
enum VisitAIService {
    /// Keeps one request bounded; the relay refuses more than 24k.
    static let maxTranscriptCharacters = 20_000

    static func summarize(_ log: Log, in context: ModelContext, now: Date = .now) async throws -> VisitSummary {
        guard AISettings.isEnabled else { throw VisitError.aiDisabled }
        guard AISettings.consent == .granted else { throw VisitError.consentRequired }
        guard let transcript = log.recording?.transcript?.trimmingCharacters(in: .whitespacesAndNewlines),
              !transcript.isEmpty else { throw VisitError.noTranscript }

        let service = try await makeService()
        let reply: String
        do {
            reply = try await service.run(AIRequest(
                action: AIRequest.summarizeVisit,
                locale: AppLanguage.code,
                content: .init(transcript: String(transcript.prefix(maxTranscriptCharacters))),
                context: .init(journeyName: log.journey?.name, visitType: log.type.isEmpty ? nil : log.type,
                               doctor: log.doctor)
            ))
        } catch let error as AIServiceError {
            throw VisitError.service(error)
        }

        guard var summary = parseSummary(reply) else { throw VisitError.unusableReply }
        summary.model = service.modelName
        summary.createdAt = now

        log.visitSummaryJSON = try encodedString(summary)
        log.updatedAt = now
        try? context.save()
        return summary
    }

    /// Translates every question that has no English yet, and leaves the ones
    /// that already do alone.
    @discardableResult
    static func translateQuestions(for log: Log, in context: ModelContext, now: Date = .now) async throws -> VisitQuestions {
        guard AISettings.isEnabled else { throw VisitError.aiDisabled }
        guard AISettings.consent == .granted else { throw VisitError.consentRequired }

        var questions = log.visitQuestions
        let pending = questions.items.filter { ($0.translated ?? "").isEmpty }
        guard !pending.isEmpty else { return questions }

        let service = try await makeService()
        let reply: String
        do {
            reply = try await service.run(AIRequest(
                action: AIRequest.translateQuestions,
                locale: AppLanguage.code,
                content: .init(questions: pending.map(\.text)),
                context: .init(journeyName: log.journey?.name)
            ))
        } catch let error as AIServiceError {
            throw VisitError.service(error)
        }

        guard let translations = parseTranslations(reply), !translations.isEmpty else {
            throw VisitError.unusableReply
        }
        // Matched by position: the relay is told to keep the order, and the
        // original is compared as a second check.
        for (offset, item) in pending.enumerated() {
            guard offset < translations.count else { break }
            let translation = translations[offset]
            guard let index = questions.items.firstIndex(where: { $0.id == item.id }) else { continue }
            questions.items[index].translated = translation.translated
        }
        questions.updatedAt = now

        log.questionsJSON = try encodedString(questions)
        log.updatedAt = now
        try? context.save()
        return questions
    }

    static func save(_ questions: VisitQuestions, to log: Log, in context: ModelContext, now: Date = .now) {
        var updated = questions
        updated.updatedAt = now
        log.questionsJSON = try? encodedString(updated)
        log.updatedAt = now
        try? context.save()
    }

    // MARK: - Parsing

    struct Translation: Codable, Equatable {
        var original: String
        var translated: String
    }

    private struct TranslationsReply: Codable {
        var translations: [Translation]
    }

    static func parseSummary(_ reply: String) -> VisitSummary? {
        guard let data = jsonBody(of: reply),
              let summary = try? ExplainService.decoder.decode(VisitSummary.self, from: data),
              !summary.saidPlain.isEmpty else { return nil }
        return summary
    }

    static func parseTranslations(_ reply: String) -> [Translation]? {
        guard let data = jsonBody(of: reply),
              let decoded = try? ExplainService.decoder.decode(TranslationsReply.self, from: data) else { return nil }
        let usable = decoded.translations.filter { !$0.translated.trimmingCharacters(in: .whitespaces).isEmpty }
        return usable.isEmpty ? nil : usable
    }

    /// Accepts a bare JSON object or one wrapped in ```json fences.
    private static func jsonBody(of reply: String) -> Data? {
        var body = reply.trimmingCharacters(in: .whitespacesAndNewlines)
        if let start = body.firstIndex(of: "{"), let end = body.lastIndex(of: "}"), start < end {
            body = String(body[start...end])
        }
        return body.data(using: .utf8)
    }

    private static func encodedString(_ value: some Encodable) throws -> String {
        String(data: try ExplainService.encoder.encode(value), encoding: .utf8) ?? ""
    }

    /// Same gate as the report explanation: the signed transaction (or, in a
    /// Debug build, the internal credential) travels with the request.
    private static func makeService() async throws -> any AIService {
        let entitlement = await SubscriptionService.shared.entitlementToken()
        do {
            return try AISettings.makeService(entitlement: entitlement)
        } catch let error as AIServiceError {
            throw VisitError.service(error)
        }
    }
}
