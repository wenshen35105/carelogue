import SwiftUI
import SwiftData

@main
struct CarelogueApp: App {
    var body: some Scene {
        WindowGroup {
            JourneyListView()
                .environment(\.locale, Theme.locale)
                .tint(Theme.accent)
        }
        .modelContainer(for: [Journey.self, Log.self, Artifact.self, Profile.self])
    }
}
