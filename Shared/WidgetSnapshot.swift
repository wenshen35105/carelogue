import Foundation

// M8 T58 · shared by the app and the widget extension (Shared/ is compiled
// into both). The widget never opens the SwiftData store: the app writes
// this small read-only snapshot into the App Group after every save, and
// the widget only reads it.

struct WidgetSnapshot: Codable, Equatable {
    struct Item: Codable, Equatable {
        var logID: UUID
        var journeyID: UUID
        var journeyName: String
        /// Already localized by the app: "面诊", "随手记".
        var title: String
        var date: Date
        /// The visit's place, or the record's first line.
        var detail: String?
    }

    /// The soonest upcoming visit in an active journey.
    var nextVisit: Item?
    /// The latest record that has already happened, when no visit is ahead.
    var latest: Item?
    /// Where 记一笔 writes: the most recently active journey.
    var quickNoteJourneyID: UUID?
    /// The app's language ("zh-Hans" / "en"), so the widget's own words and
    /// dates match the titles the app wrote — not the device's language.
    var language: String?

    static let appGroup = "group.ca.carelogue.app"

    private static var fileURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appendingPathComponent("widget-snapshot.json")
    }

    static func load() -> WidgetSnapshot? {
        guard let url = fileURL, let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    /// Writes the snapshot; false when there is no App Group to write to.
    @discardableResult
    func save() -> Bool {
        guard let url = Self.fileURL, let data = try? JSONEncoder().encode(self) else { return false }
        return (try? data.write(to: url, options: .atomic)) != nil
    }
}

/// carelogue:// links from the widget into the app.
enum DeepLink: Equatable {
    case home
    case journey(UUID)
    case log(UUID)
    /// A new quick note in that journey (or just the app, with none).
    case quickNote(UUID?)

    static let scheme = "carelogue"

    var url: URL {
        switch self {
        case .home: return URL(string: "\(Self.scheme)://home")!
        case .journey(let id): return URL(string: "\(Self.scheme)://journey/\(id.uuidString)")!
        case .log(let id): return URL(string: "\(Self.scheme)://log/\(id.uuidString)")!
        case .quickNote(let id):
            return URL(string: "\(Self.scheme)://quick-note" + (id.map { "/\($0.uuidString)" } ?? ""))!
        }
    }

    init?(url: URL) {
        guard url.scheme == Self.scheme else { return nil }
        let id = url.pathComponents.dropFirst().first.flatMap(UUID.init(uuidString:))
        switch url.host {
        case "home": self = .home
        case "journey": guard let id else { return nil }; self = .journey(id)
        case "log": guard let id else { return nil }; self = .log(id)
        case "quick-note": self = .quickNote(id)
        default: return nil
        }
    }
}
