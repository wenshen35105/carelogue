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
