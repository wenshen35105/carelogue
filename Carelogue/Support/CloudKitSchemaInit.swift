#if DEBUG
import CoreData
import Foundation
import SwiftData

/// Debug builds only (M8 release prep): pushes every record type and field
/// of the private-database store into the CloudKit *Development* schema in
/// one go, through Apple's `initializeCloudKitSchema()`. CloudKit only
/// creates a field the first time a non-empty value is saved, so simply
/// using the app leaves optional fields (diastolic, subject, Health ids, …)
/// out — and what Development lacks can't be deployed to Production.
///
/// Runs against a throwaway store file so the live store is untouched; the
/// sample records it uploads are deleted again by CloudKit itself.
enum CloudKitSchemaInit {
    static func run() throws {
        guard let model = NSManagedObjectModel.makeManagedObjectModel(
            for: [Journey.self, Log.self, Artifact.self, Profile.self, Medication.self, MedicationIntake.self]
        ) else {
            throw NSError(domain: "CloudKitSchemaInit", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Could not build the Core Data model"])
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("cloudkit-schema-init.store")
        let description = NSPersistentStoreDescription(url: url)
        description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
            containerIdentifier: ShareChannel.containerIdentifier)
        description.shouldAddStoreAsynchronously = false

        let container = NSPersistentCloudKitContainer(name: "Carelogue", managedObjectModel: model)
        container.persistentStoreDescriptions = [description]
        var loadError: Error?
        container.loadPersistentStores { _, error in loadError = error }
        if let loadError { throw loadError }

        try container.initializeCloudKitSchema()

        for store in container.persistentStoreCoordinator.persistentStores {
            try container.persistentStoreCoordinator.remove(store)
        }
        try? FileManager.default.removeItem(at: url)
    }
}
#endif
