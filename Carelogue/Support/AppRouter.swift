import Observation
import SwiftData
import SwiftUI

/// Screens reached from outside the normal tap path (M8): a notification tap
/// or a widget. The Journeys stack binds its path here, so opening a route is
/// just replacing that path.
enum AppDestination: Hashable {
    case medications
}

enum AppRoute: Equatable {
    case medications
    case journey(UUID)
    case log(UUID)
}

@MainActor
@Observable
final class AppRouter {
    static let shared = AppRouter()

    var path = NavigationPath()
    /// A widget's 记一笔 (T58): the journey to write a quick note in. The
    /// Journeys root presents the editor, over whatever the stack shows.
    var quickNoteJourney: UUID?

    /// carelogue:// links from the widget.
    func handle(_ url: URL) {
        guard let link = DeepLink(url: url) else { return }
        switch link {
        case .home:
            path = NavigationPath()
        case .journey(let id):
            open(.journey(id))
        case .log(let id):
            open(.log(id))
        case .quickNote(let id):
            guard let id else { path = NavigationPath(); return }
            open(.journey(id))
            quickNoteJourney = id
        }
    }

    func open(_ route: AppRoute, context: ModelContext? = nil) {
        let context = context ?? CarelogueApp.modelContainer?.mainContext
        var fresh = NavigationPath()
        switch route {
        case .medications:
            fresh.append(AppDestination.medications)
        case .journey(let id):
            guard let journey = Self.first(Journey.self, in: context, where: { $0.id == id }) else { return }
            fresh.append(journey)
        case .log(let id):
            guard let log = Self.first(Log.self, in: context, where: { $0.id == id }),
                  let journey = log.journey
            else { return }
            fresh.append(journey)
            fresh.append(log)
        }
        path = fresh
    }

    /// Fetch-and-filter; the stores are small.
    private static func first<T: PersistentModel>(_ type: T.Type, in context: ModelContext?,
                                                  where match: (T) -> Bool) -> T? {
        ((try? context?.fetch(FetchDescriptor<T>())) ?? []).first(where: match)
    }
}
