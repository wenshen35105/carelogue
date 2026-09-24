import Foundation

/// One AI task as the app describes it (T31): the action, the content it
/// applies to, and structured context — never prose. The prompt, the guard
/// rails and the output language template live on the relay
/// (`server/src/prompt.js`), so they can be corrected without an app update
/// and are not sitting in the binary.
nonisolated struct AIRequest: Encodable, Sendable {
    /// Each one matches a key in the relay's ACTIONS table.
    static let explainReport = "explain_report"
    /// T32: the transcript of a visit the patient recorded themselves.
    static let summarizeVisit = "summarize_visit"
    /// T32: the patient's own questions, put into English for the doctor.
    static let translateQuestions = "translate_questions"

    /// Whichever field the action calls for; the rest are simply absent.
    struct Content: Encodable, Sendable {
        /// Report text extracted on device (OCR / PDF), already trimmed.
        var reportText: String?
        /// Visit transcript produced on device (T32) — the audio stays here.
        var transcript: String?
        /// The questions as the patient wrote them (T32).
        var questions: [String]?

        enum CodingKeys: String, CodingKey {
            case reportText = "report_text"
            case transcript, questions
        }
    }

    /// Only the fields the user has agreed to send: with 附带档案 off, the
    /// Profile lines are simply absent, so the relay never holds them.
    struct Context: Encodable, Sendable {
        var journeyName: String?
        var allergies: String?
        var medications: String?
        /// Encounter sub-type (面诊 / 体检 …) and doctor, for a visit summary.
        var visitType: String?
        var doctor: String?

        enum CodingKeys: String, CodingKey {
            case journeyName = "journey_name"
            case visitType = "visit_type"
            case allergies, medications, doctor
        }
    }

    var action: String
    /// "zh-Hans" / "en" — picks the relay's template, and with it the language
    /// every string in the reply is written in.
    var locale: String
    var content: Content
    var context: Context = Context()
}

/// Provider-agnostic AI call (spec §5: the model call lives behind one
/// interface so swapping / adding a provider touches only this layer).
protocol AIService: Sendable {
    /// Shown in Settings and stored with each explanation, e.g. "deepseek-chat".
    var modelName: String { get }

    /// Sends one task and returns the assistant's raw text.
    func run(_ request: AIRequest) async throws -> String
}

enum AIServiceError: LocalizedError, Equatable {
    /// No active Carelogue Plus subscription on this device (T27).
    case notSubscribed
    case subscriptionExpired
    /// The relay refused the prompt as too long for one request.
    case reportTooLong
    case offline
    case timeout
    case rateLimited
    case server(Int)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .notSubscribed: return String(localized: "AI 解释需要 Carelogue Plus 订阅")
        case .subscriptionExpired: return String(localized: "订阅已到期，续订后可以继续使用 AI 解释")
        case .reportTooLong: return String(localized: "这份报告的文字太长，试试只解释其中一页")
        case .offline: return String(localized: "网络未连接，请检查网络后重试")
        case .timeout: return String(localized: "请求超时，请稍后重试")
        case .rateLimited: return String(localized: "请求太频繁，请稍后再试")
        case .server(let code): return String(localized: "模型服务暂时不可用（\(code)）")
        case .invalidResponse: return String(localized: "模型返回的内容无法识别")
        }
    }
}

/// Where the AI key and switches live. The key is in the Keychain; the
/// switches are plain per-device preferences.
enum AISettings {
    /// UserDefaults keys (used with @AppStorage). Both default to on.
    static let enabledKey = "ai.enabled"
    /// Send Profile allergies / medications along as context (spec §5b).
    static let includeProfileKey = "ai.includeProfile"

    /// First-use consent (spec §7): "" = not asked / declined,
    /// "granted", "revoked" (withdrawn in Settings; AI entry disabled).
    static let consentKey = "ai.consent"

    enum Consent: String {
        case undecided = ""
        case granted
        case revoked
    }

    static var consent: Consent {
        Consent(rawValue: UserDefaults.standard.string(forKey: consentKey) ?? "") ?? .undecided
    }

    static var isEnabled: Bool { UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true }
    static var includesProfile: Bool { UserDefaults.standard.object(forKey: includeProfileKey) as? Bool ?? true }

    /// The provider explain calls go through (T27): Carelogue's own relay,
    /// authorised by the App Store transaction StoreKit hands us — or, in a
    /// Debug build, by the internal credential (T30). Since T31 there is no
    /// second path: the prompt only exists on the relay, so a direct
    /// provider client could not build one. DEBUG builds can still swap in a
    /// scripted fake for UI tests.
    static func makeService(entitlement: String?) throws -> any AIService {
        #if DEBUG
        if let fake = UITestSupport.fakeAIService { return fake }
        #endif
        guard let entitlement else { throw AIServiceError.notSubscribed }
        return CarelogueServerService(entitlementToken: entitlement)
    }
}
