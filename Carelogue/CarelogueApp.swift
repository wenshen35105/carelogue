import SwiftUI
import SwiftData

@main
struct CarelogueApp: App {
    /// Set in init: the UIKit scene delegate (share acceptance, T39) lives
    /// outside SwiftUI and needs a way back to the store.
    static var modelContainer: ModelContainer?

    @UIApplicationDelegateAdaptor(ShareAppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    private let container: ModelContainer

    init() {
        // CloudKit-backed private database (T23); CloudSync falls back to a
        // local store if the container can't be opened.
        container = CloudSync.makeContainer()
        CarelogueApp.modelContainer = container
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
                // T39: watch local saves (debounced push) and subscription
                // pushes (pull), plus a pull+push on every activation.
                .task { ShareChannel.start(context: container.mainContext) }
                .onChange(of: scenePhase) { _, phase in
                    guard phase == .active else { return }
                    Task { @MainActor in
                        await ShareChannel.syncAll(in: container.mainContext)
                    }
                }
        }
        .modelContainer(container)
    }
}
