import Foundation

/// Provider-agnostic chat completion (spec §5: the model call lives behind
/// one interface so swapping / adding a provider touches only this layer).
protocol AIService: Sendable {
    /// Shown in Settings and stored with each explanation, e.g. "deepseek-chat".
    var modelName: String { get }

    /// Sends one system + user message pair and returns the assistant's raw
    /// text. With `json: true` the provider is asked for a JSON object.
    func complete(system: String, user: String, json: Bool) async throws -> String
}

enum AIServiceError: LocalizedError, Equatable {
    case missingKey
    case offline
    case timeout
    case unauthorized
    case insufficientBalance
    case rateLimited
    case server(Int)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .missingKey: return String(localized: "还没有填写 API Key，请到设置里添加")
        case .offline: return String(localized: "网络未连接，请检查网络后重试")
        case .timeout: return String(localized: "请求超时，请稍后重试")
        case .unauthorized: return String(localized: "API Key 无效，请到设置里检查")
        case .insufficientBalance: return String(localized: "AI 服务账户余额不足")
        case .rateLimited: return String(localized: "请求太频繁，请稍后再试")
        case .server(let code): return String(localized: "模型服务暂时不可用（\(code)）")
        case .invalidResponse: return String(localized: "模型返回的内容无法识别")
        }
    }
}

/// Where the AI key and switches live. The key is in the Keychain; the
/// switches are plain per-device preferences.
enum AISettings {
    static let keychainAccount = "deepseek-api-key"

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

    static var apiKey: String? {
        guard let key = KeychainStore.string(for: keychainAccount), !key.isEmpty else { return nil }
        return key
    }

    static func setAPIKey(_ key: String?) {
        let trimmed = key?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty {
            KeychainStore.remove(keychainAccount)
        } else {
            KeychainStore.set(trimmed, for: keychainAccount)
        }
    }

    /// "sk-••••••••9a2F"
    static func masked(_ key: String) -> String {
        let prefix = key.hasPrefix("sk-") ? "sk-" : ""
        return prefix + String(repeating: "•", count: 8) + String(key.suffix(4))
    }

    /// The provider explain calls go through. DEBUG builds can swap in a
    /// scripted fake for UI tests (see UITestSupport).
    static func makeService() throws -> any AIService {
        #if DEBUG
        if let fake = UITestSupport.fakeAIService { return fake }
        #endif
        guard let key = apiKey else { throw AIServiceError.missingKey }
        return DeepSeekService(apiKey: key)
    }
}
