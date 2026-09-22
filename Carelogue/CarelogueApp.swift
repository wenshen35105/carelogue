import SwiftUI
import SwiftData

@main
struct CarelogueApp: App {
    private let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(for: Journey.self, Log.self, Artifact.self, Profile.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
        #if DEBUG
        UITestSupport.prepare(container.mainContext)
        #endif
    }

    var body: some Scene {
        WindowGroup {
            JourneyListView()
                .environment(\.locale, Theme.locale)
                .tint(Theme.accent)
        }
        .modelContainer(container)
    }
}
