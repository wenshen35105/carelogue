import Foundation

/// The language the app is actually running in (iOS per-app language:
/// Settings → Carelogue → Preferred Language). Chinese UI keeps the
/// "中文 English" side-by-side style; English UI is English only.
enum AppLanguage {
    /// "zh-Hans" or "en" — whichever localization the bundle resolved to.
    static let code: String = Bundle.main.preferredLocalizations.first ?? "en"

    static let isChinese: Bool = code.hasPrefix("zh")

    /// Date / number formatting follows the app language (not the device's),
    /// keeping the device region for conventions such as week start.
    static let locale: Locale = {
        var components = Locale.Components(identifier: code)
        components.region = Locale.current.region
        return Locale(components: components)
    }()

    /// English sub-label shown next to a Chinese title; nil in English UI,
    /// where the primary text is already English.
    static func gloss(_ english: String?) -> String? {
        isChinese ? english : nil
    }
}
