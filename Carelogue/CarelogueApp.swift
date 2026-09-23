import SwiftUI
import SwiftData

@main
struct CarelogueApp: App {
    private let container: ModelContainer

    init() {
        // CloudKit-backed private database (T23); CloudSync falls back to a
        // local store if the container can't be opened.
        container = CloudSync.makeContainer()
        #if DEBUG
        UITestSupport.prepare(container.mainContext)
        #endif
    }

    var body: some Scene {
        WindowGroup {
            JourneyListView()
                .environment(\.locale, AppLanguage.locale)
                .tint(Theme.accent)
                // Loads the product and the current entitlement, and keeps
                // watching for renewals and purchases from other devices (T27).
                .task { SubscriptionService.shared.start() }
        }
        .modelContainer(container)
    }
}
