import CloudKit
import SwiftData
import SwiftUI
import UIKit

/// CloudKit share acceptance arrives on a UIKit *scene* delegate callback —
/// not the app delegate — and a pure SwiftUI app has neither (this was one of
/// the pitfalls in docs/ck-share-study.md §四). The app delegate below hands
/// UIKit a scene configuration with `ShareSceneDelegate` attached; SwiftUI
/// keeps building the window content exactly as before.
final class ShareAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Silent pushes for the CKDatabaseSubscription wake-ups (T39). They
        // carry no alert; without registration they only arrive in the
        // foreground, which the foreground sync already covers.
        UIApplication.shared.registerForRemoteNotifications()
        return true
    }

    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = ShareSceneDelegate.self
        return configuration
    }

    /// A CKDatabaseSubscription push. CloudKit notifications carry a "ck"
    /// key; `handleRemoteNotification` filters and runs the pull.
    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping @Sendable (UIBackgroundFetchResult) -> Void) {
        Task { @MainActor in
            let handled = await ShareChannel.handleRemoteNotification(userInfo)
            completionHandler(handled ? .newData : .noData)
        }
    }
}

/// Receives the accepted share when the user taps the invite link, and routes
/// it into ShareChannel. Import failures post `ShareChannel.didFailImport` so
/// the list can say so — acceptance itself has no UI of ours on screen.
///
/// Two doors, both needed: a running app gets the window-scene callback; an
/// app launched *by* the tap gets the metadata in the connection options
/// instead, and the callback never fires. (The callback's Swift name is
/// `windowScene(_:…)` — a `scene(_:…)` spelling compiles but is never called.)
final class ShareSceneDelegate: NSObject, UIWindowSceneDelegate {
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        // SwiftUI still builds the window; this only picks up a cold-launch
        // invite.
        if let metadata = connectionOptions.cloudKitShareMetadata {
            accept(metadata)
        }
    }

    func windowScene(_ windowScene: UIWindowScene,
                     userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata) {
        accept(cloudKitShareMetadata)
    }

    private func accept(_ metadata: CKShare.Metadata) {
        Task { @MainActor in
            // On a cold launch the store may be a moment behind the scene.
            while CarelogueApp.modelContainer == nil {
                try? await Task.sleep(for: .milliseconds(100))
            }
            guard let context = CarelogueApp.modelContainer?.mainContext else { return }
            do {
                try await ShareChannel.accept(metadata: metadata, context: context)
            } catch {
                NotificationCenter.default.post(
                    name: ShareChannel.didFailImport, object: nil,
                    userInfo: ["error": error.localizedDescription]
                )
            }
        }
    }
}
