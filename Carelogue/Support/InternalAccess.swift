#if DEBUG
import Foundation

/// The internal unlock channel (T30). Carelogue Plus is not on sale yet, so a
/// Debug build carries a shared credential instead of an App Store
/// transaction: the relay accepts it in place of a signed receipt (see
/// `server/src/index.js`), and everything above this — the explain flow, the
/// AI entry points, the subscription-gated UI — behaves as if subscribed.
///
/// Two things keep this out of the shipped app:
///
/// 1. The whole file, and every call site, is inside `#if DEBUG`, so no part
///    of it is compiled into a Release archive.
/// 2. The credential itself is never in the source tree or in any binary. It
///    is pasted once into Settings on a Debug build and lives in this
///    device's Keychain, so even the Debug archive carries nothing secret.
///
/// The matching server secret is deleted before the public launch (T37).
enum InternalAccess {
    /// Same Keychain service as the AI key, a different account.
    static let keychainAccount = "internal-access-key"

    /// The server refuses anything shorter, so the app does not bother
    /// storing it either.
    static let minimumLength = 24

    static var credential: String? {
        guard let value = KeychainStore.string(for: keychainAccount), !value.isEmpty else { return nil }
        return value
    }

    /// True when this build should behave as subscribed. UI tests pin the
    /// subscription state explicitly, and that always wins — otherwise a
    /// credential left on the simulator would quietly change what they see.
    @MainActor
    static var isUnlocked: Bool {
        UITestSupport.forcedSubscriptionStatus == nil && credential != nil
    }

    /// Off the main actor (`AISettings.makeService` runs wherever the explain
    /// task does), so this reads the Keychain without the UI-test guard; the
    /// token it pairs with already went through `isUnlocked`.
    static var hasCredential: Bool { credential != nil }

    /// Stores a pasted credential, or clears it when blank / too short.
    @discardableResult
    static func setCredential(_ value: String?) -> Bool {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard trimmed.count >= minimumLength else {
            KeychainStore.remove(keychainAccount)
            return trimmed.isEmpty
        }
        return KeychainStore.set(trimmed, for: keychainAccount)
    }

    /// "••••••••7f3a" — enough to tell two credentials apart, not enough to
    /// read one off a screenshot.
    static func masked(_ value: String) -> String {
        String(repeating: "•", count: 8) + String(value.suffix(4))
    }
}
#endif
