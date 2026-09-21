import Foundation
import SwiftData

enum JourneyTemplate: String, Codable, CaseIterable {
    case pregnancy
    case toothExtraction
    case custom
}

enum JourneyStatus: String, Codable, CaseIterable {
    case active
    case done
}

@Model
final class Journey {
    var id: UUID = UUID()
    var name: String = ""
    var templateRaw: String = JourneyTemplate.custom.rawValue
    var statusRaw: String = JourneyStatus.active.rawValue
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    @Relationship(deleteRule: .cascade, inverse: \Log.journey)
    var logs: [Log] = []

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
