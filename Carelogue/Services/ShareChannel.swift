import CloudKit
import Foundation
import SwiftData

/// Route B bridge (T39, docs/ck-share-study.md §四): the SwiftData store stays
/// the local source of truth, untouched. A shared Journey is *copied* into its
/// own custom CloudKit zone as plain CKRecords under a CKShare; remote edits
/// flow back into the local store. Everything stays inside the Apple
/// ecosystem — nothing transits any other server.
///
/// Shape of the channel:
///
/// - one custom zone per shared Journey (`journey-<uuid>`), created by whoever
///   starts the share; the owner addresses it in their private database,
///   participants in the shared database (CloudKit resolves the mapping)
/// - one CKRecord tree per zone: Journey root, Log children, Artifact
///   grandchildren, linked with `record.parent` so the share covers the tree
/// - both sides run the same `sync`: an incremental pull driven by a stored
///   zone change token, then a push of locally-dirty records. There is no
///   polling; wake-ups come from CKDatabaseSubscription pushes plus app
///   activation.
///
/// Conflict policy (deliberately coarse, stated in the share info sheet):
/// last write wins per record on `updatedAt`; attachments are never merged —
/// an updated attachment record replaces the old one whole. When a share is
/// revoked, the other side's local copy stays where it is and simply stops
/// updating (CloudKit's own behavior, and our copy says so).
enum ShareChannel {
    static let containerIdentifier = "iCloud.ca.carelogue.app"

    /// True while UI tests drive the share UI without an account
    /// (-uitest-fake-share): every network path below short-circuits and the
    /// views render purely from the model fields.
    static var simulated = false

    static let container = CKContainer(identifier: containerIdentifier)

    // MARK: - Errors

    enum ShareError: LocalizedError {
        case noAccount
        case notShared
        case alreadyShared
        case foreignShare

        var errorDescription: String? {
            switch self {
            case .noAccount: return String(localized: "需要登录 iCloud 才能共享")
            case .notShared: return String(localized: "这段旅程还没有开启共享")
            case .alreadyShared: return String(localized: "这段旅程已经在共享中了")
            case .foreignShare: return String(localized: "这个共享不是来自 Carelogue")
            }
        }
    }

    // MARK: - Record shape

    enum RecordType {
        static let journey = "Journey"
        static let log = "Log"
        static let artifact = "Artifact"

        /// Our record names are "<prefix>-<uuid>", so the prefix carries the
        /// type. Matched with the dash: a CKShare's own record is named by a
        /// bare UUID, whose second character is always hex — it must classify
        /// as nothing, or the push diff would mistake it for a deleted local
        /// record and delete the share itself.
        static func from(recordName: String) -> String? {
            switch recordName.prefix(2) {
            case "j-": return journey
            case "l-": return log
            case "a-": return artifact
            default: return nil
            }
        }
    }

    enum Field {
        static let name = "name"
        static let templateRaw = "templateRaw"
        static let statusRaw = "statusRaw"
        static let type = "type"
        static let kindRaw = "kindRaw"
        static let occurredAt = "occurredAt"
        static let note = "note"
        static let location = "location"
        static let doctor = "doctor"
        static let value = "value"
        static let unit = "unit"
        static let visitSummaryJSON = "visitSummaryJSON"
        static let questionsJSON = "questionsJSON"
        static let fileName = "fileName"
        static let mime = "mime"
        static let aiExplainJSON = "aiExplainJSON"
        static let transcript = "transcript"
        static let fileData = "fileData"
        static let createdAt = "createdAt"
        static let updatedAt = "updatedAt"

        /// Everything except the binary — what pull and diff fetches ask for.
        static let metadataKeys: [CKRecord.FieldKey] = [
            name, templateRaw, statusRaw, type, kindRaw, occurredAt, note, location, doctor,
            value, unit, visitSummaryJSON, questionsJSON, fileName, mime, aiExplainJSON,
            transcript, createdAt, updatedAt,
        ]
    }

    static func recordName(prefix: String, id: UUID) -> String { "\(prefix)-\(id.uuidString)" }

    static func uuid(fromRecordName name: String) -> UUID? {
        guard let dash = name.firstIndex(of: "-") else { return nil }
        return UUID(uuidString: String(name[name.index(after: dash)...]))
    }

    // MARK: - Notifications (the UI listens)

    /// Posted after a share import finished. userInfo["journey"] = journey UUID.
    static let didImport = Notification.Name("carelogue.share.didImport")
    /// Posted when a share ended remotely (revoked or root deleted).
    /// userInfo["journey"] = journey UUID.
    static let didEnd = Notification.Name("carelogue.share.didEnd")
    /// Posted when accepting a share failed. userInfo["error"] = message.
    static let didFailImport = Notification.Name("carelogue.share.didFailImport")

    // MARK: - Identity / database routing

    private static var cachedUserID: String?

    /// This account's CloudKit user record name, cached after the first call.
    static func myUserID() async throws -> String {
        if let cachedUserID { return cachedUserID }
        let id = try await container.userRecordID().recordName
        cachedUserID = id
        return id
    }

    static func isAvailable() async -> Bool {
        (try? await container.accountStatus()) == .available
    }

    /// Which database the journey's zone lives in, seen from this device: the
    /// share owner keeps it in their private database; everyone else reads it
    /// through the shared database.
    static func database(for journey: Journey) async -> CKDatabase {
        if let ownerID = journey.ownerID, let mine = try? await myUserID(), ownerID != mine {
            return container.sharedCloudDatabase
        }
        return container.privateCloudDatabase
    }

    static func zoneID(for journey: Journey) -> CKRecordZone.ID? {
        guard let owner = journey.shareZoneOwnerName else { return nil }
        return CKRecordZone.ID(zoneName: "journey-\(journey.id.uuidString)", ownerName: owner)
    }

    /// The zone as the creating (owner) device addresses it.
    static func ownZoneID(for journey: Journey) -> CKRecordZone.ID {
        CKRecordZone.ID(zoneName: "journey-\(journey.id.uuidString)", ownerName: CKCurrentUserDefaultName)
    }

    // MARK: - Zone change tokens

    private static func tokenKey(_ zoneID: CKRecordZone.ID) -> String {
        "share.token.\(zoneID.zoneName).\(zoneID.ownerName)"
    }

    private static func storedToken(for zoneID: CKRecordZone.ID) -> CKServerChangeToken? {
        guard let data = UserDefaults.standard.data(forKey: tokenKey(zoneID)) else { return nil }
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: data)
    }

    private static func storeToken(_ token: CKServerChangeToken?, for zoneID: CKRecordZone.ID) {
        guard let token,
              let data = try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true)
        else { return }
        UserDefaults.standard.set(data, forKey: tokenKey(zoneID))
    }

    static func clearToken(for zoneID: CKRecordZone.ID) {
        UserDefaults.standard.removeObject(forKey: tokenKey(zoneID))
    }

    // MARK: - Record builders

    private static func makeRecord(for journey: Journey, zoneID: CKRecordZone.ID) -> CKRecord {
        let record = CKRecord(recordType: RecordType.journey,
                              recordID: CKRecord.ID(recordName: recordName(prefix: "j", id: journey.id), zoneID: zoneID))
        apply(journey, onto: record)
        return record
    }

    private static func makeRecord(for log: Log, zoneID: CKRecordZone.ID, parent: Journey) -> CKRecord {
        let record = CKRecord(recordType: RecordType.log,
                              recordID: CKRecord.ID(recordName: recordName(prefix: "l", id: log.id), zoneID: zoneID))
        record.parent = CKRecord.Reference(recordID: CKRecord.ID(recordName: recordName(prefix: "j", id: parent.id), zoneID: zoneID), action: .none)
        apply(log, onto: record)
        return record
    }

    private static func makeRecord(for artifact: Artifact, zoneID: CKRecordZone.ID, parent: Log) -> CKRecord {
        let record = CKRecord(recordType: RecordType.artifact,
                              recordID: CKRecord.ID(recordName: recordName(prefix: "a", id: artifact.id), zoneID: zoneID))
        record.parent = CKRecord.Reference(recordID: CKRecord.ID(recordName: recordName(prefix: "l", id: parent.id), zoneID: zoneID), action: .none)
        apply(artifact, onto: record)
        record[Field.fileData] = asset(from: artifact.fileData)
        return record
    }

    /// Copies this device's field values onto a record, keeping any change
    /// tag it already carries so the save can be conflict-checked.
    private static func apply(_ journey: Journey, onto record: CKRecord) {
        record[Field.name] = journey.name
        record[Field.templateRaw] = journey.templateRaw
        record[Field.statusRaw] = journey.statusRaw
        record[Field.createdAt] = journey.createdAt
        record[Field.updatedAt] = journey.updatedAt
    }

    private static func apply(_ log: Log, onto record: CKRecord) {
        record[Field.kindRaw] = log.kindRaw
        record[Field.type] = log.type
        record[Field.occurredAt] = log.occurredAt
        record[Field.note] = log.note
        record[Field.location] = log.location
        record[Field.doctor] = log.doctor
        record[Field.value] = log.value
        record[Field.unit] = log.unit
        record[Field.visitSummaryJSON] = log.visitSummaryJSON
        record[Field.questionsJSON] = log.questionsJSON
        record[Field.createdAt] = log.createdAt
        record[Field.updatedAt] = log.updatedAt
    }

    /// Artifacts have no `updatedAt` of their own, so the record's stamp is
    /// simply whenever it was last written; content compare does the rest.
    private static func apply(_ artifact: Artifact, onto record: CKRecord) {
        record[Field.fileName] = artifact.fileName
        record[Field.mime] = artifact.mime
        record[Field.createdAt] = artifact.createdAt
        record[Field.updatedAt] = artifact.createdAt
        record[Field.aiExplainJSON] = artifact.aiExplainJSON
        record[Field.transcript] = artifact.transcript
    }

    /// CKAsset from in-memory data, through a temp file.
    private static func asset(from data: Data) -> CKAsset {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("share-asset-\(UUID().uuidString)")
        try? data.write(to: url)
        return CKAsset(fileURL: url)
    }

    private static func data(from asset: CKAsset?) -> Data? {
        guard let url = asset?.fileURL else { return nil }
        return try? Data(contentsOf: url)
    }

    // MARK: - Owner: create the share

    /// Builds the zone, the record tree and the CKShare, saves them atomically
    /// and stamps the journey's share metadata. Called from the sharing
    /// controller's preparation handler.
    @MainActor
    static func prepare(journey: Journey, context: ModelContext) async throws -> CKShare {
        guard await isAvailable() else { throw ShareError.noAccount }
        guard !journey.isShared else { throw ShareError.alreadyShared }

        let zoneID = ownZoneID(for: journey)
        let database = container.privateCloudDatabase
        _ = try await database.modifyRecordZones(saving: [CKRecordZone(zoneID: zoneID)], deleting: [])

        var records: [CKRecord] = [makeRecord(for: journey, zoneID: zoneID)]
        for log in journey.allLogs {
            records.append(makeRecord(for: log, zoneID: zoneID, parent: journey))
            for artifact in log.allArtifacts {
                records.append(makeRecord(for: artifact, zoneID: zoneID, parent: log))
            }
        }

        let share = CKShare(rootRecord: records[0])
        // What the invite and the system share UI show as the item's name.
        share[CKShare.SystemFieldKey.title] = journey.name
        records.append(share)
        _ = try await save(records, to: database)

        isWritingLocally = true
        journey.shareRecordID = share.recordID.recordName
        journey.ownerID = try await myUserID()
        journey.shareZoneOwnerName = zoneID.ownerName
        journey.isShared = true
        journey.lastSharedUpdatedAt = .now
        try? context.save()
        isWritingLocally = false

        await ensureSubscriptions()
        return share
    }

    /// The fetched CKShare for an already-shared journey, so the sharing
    /// controller can be opened in manage mode.
    static func existingShare(of journey: Journey) async throws -> CKShare? {
        guard journey.isShared, let shareRecordID = journey.shareRecordID,
              let zoneID = zoneID(for: journey) else { return nil }
        let database = await database(for: journey)
        return try await database.record(for: CKRecord.ID(recordName: shareRecordID, zoneID: zoneID)) as? CKShare
    }

    // MARK: - Participant: accept an invite

    /// Accepts the share and imports the whole zone into the local store as a
    /// plain SwiftData journey (the participant has no other copy of it).
    @MainActor
    static func accept(metadata: CKShare.Metadata, context: ModelContext) async throws {
        guard await isAvailable() else { throw ShareError.noAccount }
        let share = try await container.accept(metadata)
        let database = container.sharedCloudDatabase
        // CKShare.Metadata carries no zone ID; the accepted share's own record
        // lives in the shared zone, so its recordID names it (ownerName is the
        // owner's user record name, as the shared database sees it).
        let zoneID = share.recordID.zoneID

        isWritingLocally = true
        defer { isWritingLocally = false }

        // Token nil = the full zone: root, tree and share record in one fetch.
        let result = try await database.recordZoneChanges(inZoneWith: zoneID, since: nil,
                                                          desiredKeys: Field.metadataKeys)
        let records = result.modificationResultsByID.values.compactMap { try? $0.get().record }
        guard let root = records.first(where: { $0.recordType == RecordType.journey }) else {
            throw ShareError.foreignShare
        }

        let journey = upsertJourney(from: root, in: context)
        for record in records where record.recordType == RecordType.log {
            _ = upsertLog(from: record, in: journey, context: context)
        }
        // Artifact binaries come down one by one, only for records whose
        // metadata says the local copy is missing or stale.
        for record in records where record.recordType == RecordType.artifact {
            guard needsImport(record, context: context) else { continue }
            let full = try await database.record(for: record.recordID)
            upsertArtifact(from: full, in: context)
        }

        journey.shareRecordID = share.recordID.recordName
        journey.ownerID = share.owner.userIdentity.userRecordID?.recordName ?? zoneID.ownerName
        journey.shareZoneOwnerName = zoneID.ownerName
        journey.isShared = true
        journey.lastSharedUpdatedAt = .now
        try? context.save()
        storeToken(result.changeToken, for: zoneID)

        await ensureSubscriptions()
        NotificationCenter.default.post(name: didImport, object: nil, userInfo: ["journey": journey.id])
    }

    // MARK: - Sync (both sides)

    /// True while ShareChannel itself is writing to the store; the didSave
    /// observer must not answer our own writes with another sync round.
    @MainActor private static var isWritingLocally = false
    @MainActor private static var observer: (any NSObjectProtocol)?
    @MainActor private static var syncTask: Task<Void, Never>?
    @MainActor private static var syncContext: ModelContext?

    /// Starts watching saves and remote pushes. Call once at app start.
    @MainActor
    static func start(context: ModelContext) {
        guard observer == nil else { return }
        syncContext = context
        observer = NotificationCenter.default.addObserver(
            forName: ModelContext.didSave, object: nil, queue: .main
        ) { _ in
            Task { @MainActor in scheduleSync() }
        }
        Task { @MainActor in
            await syncAll(in: context)
            await ensureSubscriptions()
        }
    }

    /// Debounced: local edits settle for a moment before anything is pushed.
    @MainActor
    static func scheduleSync() {
        guard let syncContext else { return }
        syncTask?.cancel()
        syncTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            await syncAll(in: syncContext)
        }
    }

    @MainActor
    static func syncAll(in context: ModelContext) async {
        syncContext = syncContext ?? context
        guard !simulated, CloudSync.mode == .cloudKit, CloudSync.hasICloudAccount else { return }
        guard !isWritingLocally else { return }
        let shared = (try? context.fetch(FetchDescriptor<Journey>())) ?? []
        for journey in shared where journey.isShared {
            await sync(journey: journey, in: context)
        }
    }

    /// Pull, then push, for one shared journey. Pull first: applying remote
    /// additions before the push diff is what lets "the server holds a record
    /// this device lacks" mean "deleted locally" rather than "added remotely".
    @MainActor
    static func sync(journey: Journey, in context: ModelContext) async {
        guard journey.isShared, let zoneID = zoneID(for: journey) else { return }
        let database = await database(for: journey)
        // Stamped with the start time: an edit made while this round is in
        // flight is newer than the stamp, so the next round still pushes it.
        let startedAt = Date.now
        do {
            try await pull(journey: journey, zoneID: zoneID, database: database, context: context)
            try await push(journey: journey, zoneID: zoneID, database: database, context: context)
            isWritingLocally = true
            journey.lastSharedUpdatedAt = startedAt
            try? context.save()
            isWritingLocally = false
        } catch {
            handleSyncError(error, journey: journey, context: context)
        }
    }

    /// Incremental fetch of remote changes, applied to the local store.
    @MainActor
    private static func pull(journey: Journey, zoneID: CKRecordZone.ID, database: CKDatabase,
                             context: ModelContext) async throws {
        var token = storedToken(for: zoneID)
        var changedArtifacts: [CKRecord] = []

        while true {
            let result = try await database.recordZoneChanges(inZoneWith: zoneID, since: token,
                                                               desiredKeys: Field.metadataKeys)
            token = result.changeToken

            isWritingLocally = true
            for deletion in result.deletions {
                // A deleted root means the share ended — never delete the
                // local journey copy. Children deleted remotely do go.
                if RecordType.from(recordName: deletion.recordID.recordName) == RecordType.journey {
                    endShare(journey: journey, in: context)
                } else {
                    deleteLocal(recordName: deletion.recordID.recordName, context: context)
                }
            }
            for change in result.modificationResultsByID.values {
                guard case .success(let modification) = change else { continue }
                let record = modification.record
                switch record.recordType {
                case RecordType.journey:
                    applyRemote(record, to: journey)
                case RecordType.log:
                    _ = upsertLog(from: record, in: journey, context: context)
                case RecordType.artifact:
                    changedArtifacts.append(record)
                default:
                    break // the share record itself
                }
            }
            isWritingLocally = false

            guard result.moreComing else { break }
        }

        // Binary payloads: fetched only for artifacts that are missing
        // locally or whose metadata differs, so an unchanged gallery is free.
        isWritingLocally = true
        defer { isWritingLocally = false }
        for record in changedArtifacts where needsImport(record, context: context) {
            let full = try await database.record(for: record.recordID)
            upsertArtifact(from: full, in: context)
        }
        try? context.save()
        // Only now does the token move: had a binary fetch thrown above, the
        // next round must see that artifact again — otherwise push would read
        // "on the server, not here" as a local delete and remove it remotely.
        storeToken(token, for: zoneID)
    }

    /// Pushes locally-dirty records. Dirty = `updatedAt` newer than the last
    /// completed sync stamp (journeys and logs), or — for artifacts, which
    /// carry no `updatedAt` of their own — content that differs from the
    /// server's copy.
    @MainActor
    private static func push(journey: Journey, zoneID: CKRecordZone.ID, database: CKDatabase,
                             context: ModelContext) async throws {
        let stamp = journey.lastSharedUpdatedAt ?? .distantPast

        // Which of our records does the server currently hold? Metadata only.
        let enumeration = try await database.recordZoneChanges(inZoneWith: zoneID, since: nil,
                                                               desiredKeys: [Field.updatedAt])
        var serverDates: [String: Date] = [:]
        for change in enumeration.modificationResultsByID.values {
            guard case .success(let modification) = change else { continue }
            if let date = modification.record[Field.updatedAt] as? Date {
                serverDates[modification.record.recordID.recordName] = date
            }
        }

        let localTreeIDs = Set([recordName(prefix: "j", id: journey.id)]
            + journey.allLogs.map { recordName(prefix: "l", id: $0.id) }
            + journey.allLogs.flatMap { $0.allArtifacts.map { recordName(prefix: "a", id: $0.id) } })
        // Records the server holds but the local tree no longer does: deleted
        // here, so delete there. Safe only because pull ran first.
        let deletions = serverDates.keys
            .filter { RecordType.from(recordName: $0) != nil && !localTreeIDs.contains($0) }
            .map { CKRecord.ID(recordName: $0, zoneID: zoneID) }

        let journeyName = recordName(prefix: "j", id: journey.id)
        let dirtyLogs = journey.allLogs.filter { $0.updatedAt > stamp }
        // Explanation/transcript writes bump the parent log; new attachments
        // carry their own createdAt. A log can match both ways, so dedupe —
        // one modifyRecords call must not save the same record ID twice.
        var seenArtifacts: Set<UUID> = []
        let candidateArtifacts = journey.allLogs
            .flatMap { log in log.allArtifacts.filter { log.updatedAt > stamp || $0.createdAt > stamp } }
            .filter { seenArtifacts.insert($0.id).inserted }

        // Fetch current server copies of everything we may write, so saves
        // carry a change tag (.ifServerRecordUnchanged) and the artifact
        // diff has something to compare against.
        var wantedIDs: Set<String> = [journeyName]
        wantedIDs.formUnion(dirtyLogs.map { recordName(prefix: "l", id: $0.id) })
        wantedIDs.formUnion(candidateArtifacts.map { recordName(prefix: "a", id: $0.id) })
        var serverRecords: [String: CKRecord] = [:]
        for name in wantedIDs where serverDates[name] != nil {
            let id = CKRecord.ID(recordName: name, zoneID: zoneID)
            if let record = try? await database.record(for: id) {
                serverRecords[name] = record
            }
        }

        var toSave: [CKRecord] = []
        if journey.updatedAt > serverDates[journeyName] ?? .distantPast {
            if let server = serverRecords[journeyName] {
                apply(journey, onto: server)
                toSave.append(server)
            } else {
                toSave.append(makeRecord(for: journey, zoneID: zoneID))
            }
        }
        for log in dirtyLogs {
            let name = recordName(prefix: "l", id: log.id)
            if let server = serverRecords[name] {
                apply(log, onto: server)
                toSave.append(server)
            } else {
                toSave.append(makeRecord(for: log, zoneID: zoneID, parent: journey))
            }
        }
        for artifact in candidateArtifacts {
            let name = recordName(prefix: "a", id: artifact.id)
            guard let log = artifact.log else { continue }
            if let server = serverRecords[name] {
                guard artifactDiffers(server, artifact) else { continue }
                apply(artifact, onto: server)
                server[Field.fileData] = asset(from: artifact.fileData)
                server[Field.updatedAt] = Date.now
                toSave.append(server)
            } else {
                toSave.append(makeRecord(for: artifact, zoneID: zoneID, parent: log))
            }
        }

        guard !toSave.isEmpty || !deletions.isEmpty else { return }
        _ = try await save(toSave, deleting: deletions, to: database)
    }

    /// Saves with one retry on a lost race (someone wrote between our fetch
    /// and our save): refetch, apply again, save once more. Losing again
    /// means the other side was newer — last write wins, let it.
    private static func save(_ records: [CKRecord], deleting: [CKRecord.ID] = [],
                             to database: CKDatabase) async throws {
        let result = try await database.modifyRecords(saving: records, deleting: deleting,
                                                      savePolicy: .ifServerRecordUnchanged, atomically: false)
        let conflicted = result.saveResults.filter { _, outcome in
            if case .failure(let error) = outcome, (error as? CKError)?.code == .serverRecordChanged {
                return true
            }
            return false
        }
        guard !conflicted.isEmpty else { return }

        var retried: [CKRecord] = []
        for (id, _) in conflicted {
            guard let fresh = try? await database.record(for: id),
                  let original = records.first(where: { $0.recordID == id }) else { continue }
            for key in original.allKeys() {
                if let value = original[key] { fresh[key] = value }
            }
            retried.append(fresh)
        }
        _ = try await database.modifyRecords(saving: retried, deleting: [],
                                             savePolicy: .ifServerRecordUnchanged, atomically: false)
    }

    // MARK: - Local store upserts

    @MainActor
    private static func upsertJourney(from record: CKRecord, in context: ModelContext) -> Journey {
        let id = uuid(fromRecordName: record.recordID.recordName) ?? UUID()
        var journey = findJourney(id: id, context: context)
        if journey == nil {
            let fresh = Journey(id: id, name: "", template: .custom, createdAt: Date.now, updatedAt: Date.now)
            context.insert(fresh)
            journey = fresh
        }
        applyRemote(record, to: journey!)
        return journey!
    }

    @MainActor
    private static func upsertLog(from record: CKRecord, in journey: Journey, context: ModelContext) -> Log {
        let id = uuid(fromRecordName: record.recordID.recordName) ?? UUID()
        var log = findLog(id: id, context: context)
        if log == nil {
            let fresh = Log(id: id)
            context.insert(fresh)
            journey.add(fresh)
            log = fresh
        }
        log!.journey = journey
        if record[Field.updatedAt] as? Date ?? .distantPast > log!.updatedAt {
            let remote = record
            log!.kindRaw = remote[Field.kindRaw] as? String ?? log!.kindRaw
            log!.type = remote[Field.type] as? String ?? log!.type
            log!.occurredAt = remote[Field.occurredAt] as? Date ?? log!.occurredAt
            log!.note = remote[Field.note] as? String
            log!.location = remote[Field.location] as? String
            log!.doctor = remote[Field.doctor] as? String
            log!.value = remote[Field.value] as? Double
            log!.unit = remote[Field.unit] as? String
            log!.visitSummaryJSON = remote[Field.visitSummaryJSON] as? String
            log!.questionsJSON = remote[Field.questionsJSON] as? String
            log!.createdAt = remote[Field.createdAt] as? Date ?? log!.createdAt
            log!.updatedAt = remote[Field.updatedAt] as? Date ?? log!.updatedAt
        }
        return log!
    }

    @MainActor
    private static func upsertArtifact(from record: CKRecord, in context: ModelContext) {
        guard let id = uuid(fromRecordName: record.recordID.recordName) else { return }
        var artifact = findArtifact(id: id, context: context)
        if artifact == nil {
            let fresh = Artifact(id: id)
            context.insert(fresh)
            artifact = fresh
        }
        artifact!.fileName = record[Field.fileName] as? String ?? artifact!.fileName
        artifact!.mime = record[Field.mime] as? String ?? artifact!.mime
        artifact!.createdAt = record[Field.createdAt] as? Date ?? artifact!.createdAt
        artifact!.aiExplainJSON = record[Field.aiExplainJSON] as? String
        artifact!.transcript = record[Field.transcript] as? String
        if let data = data(from: record[Field.fileData] as? CKAsset), !data.isEmpty {
            artifact!.fileData = data
        }
        if let parentName = record.parent?.recordID.recordName,
           let parentUUID = uuid(fromRecordName: parentName),
           let parentLog = findLog(id: parentUUID, context: context) {
            parentLog.add(artifact!)
        }
    }

    /// True when the record's metadata says the local copy is missing or
    /// stale, i.e. the binary is worth fetching.
    @MainActor
    private static func needsImport(_ record: CKRecord, context: ModelContext) -> Bool {
        guard let id = uuid(fromRecordName: record.recordID.recordName) else { return false }
        guard let local = findArtifact(id: id, context: context) else { return true }
        return artifactDiffers(record, local)
    }

    /// Server-side field changes onto a local journey (never the share meta —
    /// that is local state describing the channel).
    @MainActor
    private static func applyRemote(_ record: CKRecord, to journey: Journey) {
        guard record[Field.updatedAt] as? Date ?? .distantPast > journey.updatedAt else { return }
        journey.name = record[Field.name] as? String ?? journey.name
        journey.templateRaw = record[Field.templateRaw] as? String ?? journey.templateRaw
        journey.statusRaw = record[Field.statusRaw] as? String ?? journey.statusRaw
        journey.createdAt = record[Field.createdAt] as? Date ?? journey.createdAt
        journey.updatedAt = record[Field.updatedAt] as? Date ?? journey.updatedAt
    }

    @MainActor
    private static func artifactDiffers(_ record: CKRecord, _ local: Artifact) -> Bool {
        (record[Field.fileName] as? String) != local.fileName
            || (record[Field.mime] as? String) != local.mime
            || (record[Field.aiExplainJSON] as? String) != local.aiExplainJSON
            || (record[Field.transcript] as? String) != local.transcript
    }

    @MainActor
    private static func deleteLocal(recordName name: String, context: ModelContext) {
        guard let id = uuid(fromRecordName: name) else { return }
        switch RecordType.from(recordName: name) {
        case RecordType.log:
            if let log = findLog(id: id, context: context) {
                context.deleteLog(log)
            }
        case RecordType.artifact:
            if let artifact = findArtifact(id: id, context: context) {
                artifact.log?.removeArtifact(id: id)
                context.delete(artifact)
            }
        default:
            break
        }
    }

    @MainActor
    private static func findJourney(id: UUID, context: ModelContext) -> Journey? {
        ((try? context.fetch(FetchDescriptor<Journey>())) ?? []).first { $0.id == id }
    }

    @MainActor
    private static func findLog(id: UUID, context: ModelContext) -> Log? {
        ((try? context.fetch(FetchDescriptor<Log>())) ?? []).first { $0.id == id }
    }

    @MainActor
    private static func findArtifact(id: UUID, context: ModelContext) -> Artifact? {
        ((try? context.fetch(FetchDescriptor<Artifact>())) ?? []).first { $0.id == id }
    }

    // MARK: - Ending shares

    /// Remote side ended the share (revoked, or the root record was deleted):
    /// the local copy stays exactly where it is, but stops syncing.
    @MainActor
    static func endShare(journey: Journey, in context: ModelContext) {
        guard journey.isShared else { return }
        journey.isShared = false
        if let zoneID = zoneID(for: journey) { clearToken(for: zoneID) }
        try? context.save()
        NotificationCenter.default.post(name: didEnd, object: nil, userInfo: ["journey": journey.id])
    }

    /// Local side stopped sharing: the owner deletes the zone (which ends it
    /// for every participant); a participant only detaches this device.
    @MainActor
    static func stopSharing(journey: Journey, in context: ModelContext) async {
        let isOwner = journey.ownerID == (try? await myUserID())
        if isOwner, let zoneID = zoneID(for: journey) {
            _ = try? await container.privateCloudDatabase
                .modifyRecordZones(saving: [], deleting: [zoneID])
        }
        endShare(journey: journey, in: context)
    }

    /// The acceptance tail (T39): folds a pre-existing local journey into the
    /// newly imported shared one, so both people end up with a single journey.
    /// Re-parented logs get a fresh `updatedAt`, so they win any conflict.
    @MainActor
    static func merge(twin: Journey, into shared: Journey, context: ModelContext) {
        isWritingLocally = true
        for log in twin.allLogs {
            shared.add(log)
            log.updatedAt = .now
        }
        twin.logs = []
        context.delete(twin)
        shared.updatedAt = .now
        try? context.save()
        isWritingLocally = false
        scheduleSync()
    }

    // MARK: - Errors

    /// Zone-level "it's gone" errors mean the share ended (revoked on this
    /// side, or the owner deleted the zone). Everything else is transient and
    /// left for the next sync to retry.
    @MainActor
    private static func handleSyncError(_ error: Error, journey: Journey, context: ModelContext) {
        switch (error as? CKError)?.code {
        case .zoneNotFound, .unknownItem, .permissionFailure, .userDeletedZone:
            endShare(journey: journey, in: context)
        default:
            break
        }
    }

    // MARK: - Push wake-ups

    /// One database subscription per side. A push arriving while the app is
    /// backgrounded wakes it (remote-notification is in the Info.plist);
    /// AppDelegate routes it to `handleRemoteNotification`.
    static func ensureSubscriptions() async {
        guard !simulated, await isAvailable() else { return }
        let pairs: [(CKDatabase, CKSubscription)] = [
            (container.sharedCloudDatabase, CKDatabaseSubscription(subscriptionID: "carelogue.share.changes.shared")),
            (container.privateCloudDatabase, CKDatabaseSubscription(subscriptionID: "carelogue.share.changes.private")),
        ]
        for (database, subscription) in pairs {
            if (try? await database.subscription(for: subscription.subscriptionID)) != nil { continue }
            _ = try? await database.modifySubscriptions(saving: [subscription], deleting: [])
        }
    }

    @MainActor
    static func handleRemoteNotification(_ userInfo: [AnyHashable: Any]) async -> Bool {
        guard userInfo["ck"] != nil || (userInfo["aps"] as? [String: Any])?["content-available"] != nil,
              let context = syncContext else { return false }
        await syncAll(in: context)
        return true
    }
}
