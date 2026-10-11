import StoreKit
import UIKit

/// M8 T51: asks iOS for the rating prompt — never a look-alike of our own,
/// never in exchange for anything (App Review 5.6.1). Whether a prompt
/// actually appears is iOS's call (and at most three times a year); all the
/// app controls is when it *asks*: once the store holds five records, on the
/// save of a new one, and then not again for 90 days.
enum ReviewPrompt {
    static let threshold = 5
    static let quietDays = 90
    static let lastRequestKey = "review.lastRequestedAt"
    /// Debug builds count requests so UI tests can see them happen.
    static let requestCountKey = "review.requestCount"

    /// The App Store page's "write a review" sheet (Settings row).
    static let writeReviewURL = URL(string: "https://apps.apple.com/app/id6815909128?action=write-review")!

    static func isDue(logCount: Int, now: Date = .now, defaults: UserDefaults = .standard) -> Bool {
        guard logCount >= threshold else { return false }
        guard let last = defaults.object(forKey: lastRequestKey) as? Date else { return true }
        return now.timeIntervalSince(last) >= Double(quietDays) * 86_400
    }

    /// Call after a new record is saved. Asks a moment later, once the
    /// editor sheet is gone, so the prompt never covers what was just typed.
    @MainActor
    static func newRecordSaved(logCount: Int) {
        guard isDue(logCount: logCount) else { return }
        UserDefaults.standard.set(Date.now, forKey: lastRequestKey)
        UserDefaults.standard.set(UserDefaults.standard.integer(forKey: requestCountKey) + 1, forKey: requestCountKey)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            let scene = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first { $0.activationState == .foregroundActive }
            if let scene { AppStore.requestReview(in: scene) }
        }
    }
}
