import Foundation
import SwiftData

enum JourneyTemplate: String, Codable, CaseIterable {
    case pregnancy
    case toothExtraction
    case custom

    var displayName: String {
        switch self {
        case .pregnancy: return String(localized: "孕期")
        case .toothExtraction: return String(localized: "拔牙")
        case .custom: return String(localized: "自定义")
        }
    }
}

enum JourneyStatus: String, Codable, CaseIterable {
    case active
    case done

    var displayName: String {
        switch self {
        case .active: return String(localized: "进行中")
        case .done: return String(localized: "已完成")
        }
    }
}

@Model
final class Journey {
    var id: UUID = UUID()
    var name: String = ""
    var templateRaw: String = JourneyTemplate.custom.rawValue
    var statusRaw: String = JourneyStatus.active.rawValue
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    // MARK: - Summary and target (M8 T55 / T56)
    //
    // Generic on purpose: no pregnancy fields. A template only *suggests*
    // values (预产期 as the target's name, 血型 as a summary key); what is
    // stored is always a plain name, date or key/value pair.
    //
    //   targetDate         the day the journey heads for (due date, surgery…)
    //   targetLabel        what the user calls that day
    //   progressStartDate  where the progress ring starts; nil = createdAt
    //   summaryItemsJSON   [{key, value}] chips under the title
    var targetDate: Date? = nil
    var targetLabel: String? = nil
    var progressStartDate: Date? = nil
    var summaryItemsJSON: String? = nil

    // MARK: - Subject (M8 T61)
    //
    // Whose health this journey records — not the same as who created it
    // (a husband's journey about his wife's pregnancy). Both nil = not
    // specified (every journey made before 1.1).
    //
    //   subjectName    how to call them ("太太", "小宝"); may be nil for "me"
    //   subjectUserID  their CloudKit user record name — or this install's
    //                  own id without iCloud — when they use Carelogue; nil
    //                  for someone who doesn't (a child with no phone)
    var subjectName: String? = nil
    var subjectUserID: String? = nil

    // MARK: - CKShare metadata (T39, route B)
    //
    // All optional-with-defaults so the migration stays additive (schema
    // freeze: sanctioned by the T39 card itself). They describe the separate
    // CKShare channel, never the SwiftData/CloudKit store the journey lives
    // in — see ShareChannel for how they are used.
    //
    //   shareRecordID       CKRecord.ID.recordName of the CKShare record
    //   ownerID             recordName of the share owner's user record
    //   shareZoneOwnerName  ownerName of the custom zone (== owner's user
    //                       record name; the participant side needs it to
    //                       address the zone in the shared database)
    //   isShared            the channel is open: push and pull are active
    //   lastSharedUpdatedAt when the last completed sync stamped the journey;
    //                       a local `updatedAt` newer than this means "dirty,
    //                       not pushed yet" (the push/pull diff is built on it)
    var shareRecordID: String? = nil
    var ownerID: String? = nil
    var shareZoneOwnerName: String? = nil
    var isShared: Bool = false
    var lastSharedUpdatedAt: Date? = nil

    /// CloudKit requires every to-many relationship to be optional (T23), so
    /// the stored property is `[Log]?`; read it through `allLogs` and change it
    /// through `add(_:)` / `removeLog(id:)`, which also keep views observing
    /// the parent array refreshed (m2-bugs #10).
    @Relationship(deleteRule: .cascade, inverse: \Log.journey)
    var logs: [Log]? = []

    var allLogs: [Log] { logs ?? [] }

    func add(_ log: Log) {
        logs = allLogs + [log]
        log.journey = self
    }

    func removeLog(id: UUID) {
        logs = allLogs.filter { $0.id != id }
    }

    var template: JourneyTemplate {
        get { JourneyTemplate(rawValue: templateRaw) ?? .custom }
        set { templateRaw = newValue.rawValue }
    }

    var status: JourneyStatus {
        get { JourneyStatus(rawValue: statusRaw) ?? .active }
        set { statusRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        name: String = "",
        template: JourneyTemplate = .custom,
        status: JourneyStatus = .active,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.templateRaw = template.rawValue
        self.statusRaw = status.rawValue
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
