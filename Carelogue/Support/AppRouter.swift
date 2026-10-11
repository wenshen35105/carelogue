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

    func open(_ route: AppRoute, context: ModelContext? = nil) {
        let context = context ?? CarelogueApp.modelContainer?.mainContext
        var fresh = NavigationPath()
        switch route {
        case .medications:
            fresh.append(AppDestination.medications)
        case .journey(let id):
            guard let journey = context.flatMap({ try? $0.fetch(FetchDescriptor<Journey>(predicate: #Predicate { $0.id == id })).first })
            else { return }
            fresh.append(journey)
        case .log(let id):
            guard let log = context.flatMap({ try? $0.fetch(FetchDescriptor<Log>(predicate: #Predicate { $0.id == id })).first }),
                  let journey = log.journey
            else { return }
            fresh.append(journey)
            fresh.append(log)
        }
        path = fresh
    }
}
