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
        }
        .modelContainer(container)
    }
}
