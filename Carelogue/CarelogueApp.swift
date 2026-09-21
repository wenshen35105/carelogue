import SwiftUI
import SwiftData

@main
struct CarelogueApp: App {
    var body: some Scene {
        WindowGroup {
            JourneyListView()
        }
        .modelContainer(for: [Journey.self, Log.self, Artifact.self, Profile.self])
    }
}
