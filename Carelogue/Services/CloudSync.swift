import Foundation
import SwiftData

/// How this launch's store is backed (T23). SwiftData syncs through CloudKit
/// on its own once the container is configured, so this exists only to build
/// the container and to tell the user, honestly, whether syncing can happen.
enum CloudSync {
    /// Set while building the ModelContainer.
    private(set) static var mode: Mode = .local

    enum Mode: Equatable {
        /// CloudKit private database — records sync between the owner's devices.
        case cloudKit
        /// Local store only: UI tests, or a build whose CloudKit container
        /// could not be opened. The app still works, nothing leaves the device.
        case local
    }

    /// True when an iCloud account is signed in on this device. Without one,
    /// the CloudKit store still works locally but nothing syncs — which is
    /// exactly what Settings needs to say.
    static var hasICloudAccount: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }

    static var isSyncing: Bool { mode == .cloudKit && hasICloudAccount }

    /// Builds the app's store. CloudKit first; a local store is the fallback
    /// so a missing entitlement or container can never stop the app from
    /// launching (and so UI tests stay hermetic).
    static func makeContainer() -> ModelContainer {
        let schema = Schema([Journey.self, Log.self, Artifact.self, Profile.self])

        #if DEBUG
        // Escape hatch for debugging a store problem without iCloud in the
        // way. UI tests deliberately do NOT set it: every launch, seeded or
        // not, must open the store the same way a real launch does.
        let preferLocal = ProcessInfo.processInfo.arguments.contains("-uitest-local-store")
        #else
        let preferLocal = false
        #endif

        if !preferLocal {
            do {
                let configuration = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
                let container = try ModelContainer(for: schema, configurations: configuration)
                mode = .cloudKit
                return container
            } catch {
                // Falls through to the local store; Settings shows "未开启".
            }
        }

        do {
            let configuration = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, configurations: configuration)
            mode = .local
            return container
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
}
