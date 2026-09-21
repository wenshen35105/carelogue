import SwiftUI
import SwiftData

@main
struct CarelogueApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Journey.self, Log.self, Artifact.self, Profile.self])
    }
}
