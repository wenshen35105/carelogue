import Foundation
import SwiftData

/// A medication plan the user set up themselves (M8 T53): a name, a dose as
/// free text, and the times of day to be reminded. Carelogue only reminds of
/// this plan — it never suggests doses or checks interactions.
@Model
final class Medication {
    var id: UUID = UUID()
    var name: String = ""
    /// Free text, e.g. "5 mg" or "1 片".
    var dose: String = ""
    /// Reminder times as minutes after midnight, comma-separated and sorted
    /// ("480,1200" = 08:00 and 20:00). Read through `reminderMinutes`.
    var timesRaw: String = ""
    /// Off = paused: kept in the list, no reminders, no check-ins.
    var isActive: Bool = true
    /// The journey this plan belongs to, if any. A plain id rather than a
    /// relationship, so deleting or unsharing a journey never touches the
    /// plan (it simply shows without a journey tag).
    var journeyID: UUID? = nil
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    /// Optional for CloudKit (T23) — read through `allIntakes`.
    @Relationship(deleteRule: .cascade, inverse: \MedicationIntake.medication)
    var intakes: [MedicationIntake]? = []

    var allIntakes: [MedicationIntake] { intakes ?? [] }

    var reminderMinutes: [Int] {
        get {
            timesRaw.split(separator: ",").compactMap { Int($0) }.filter { (0..<1440).contains($0) }
        }
        set {
            timesRaw = Array(Set(newValue)).sorted().map(String.init).joined(separator: ",")
        }
    }

    init(
        id: UUID = UUID(),
        name: String = "",
        dose: String = "",
        reminderMinutes: [Int] = [],
        isActive: Bool = true,
        journeyID: UUID? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.dose = dose
        self.isActive = isActive
        self.journeyID = journeyID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.reminderMinutes = reminderMinutes
    }
}

enum IntakeStatus: String, Codable {
    case taken
    case skipped
}

/// One check-in for one scheduled dose: "taken" or "skipped" for the slot at
/// `slotMinute` on `day`. Only today's are shown; older rows stay as history.
@Model
final class MedicationIntake {
    var id: UUID = UUID()
    /// Start of the calendar day the dose was scheduled for.
    var day: Date = Date.now
    /// The scheduled time (minutes after midnight) this check-in answers.
    var slotMinute: Int = 0
    var statusRaw: String = IntakeStatus.taken.rawValue
    var recordedAt: Date = Date.now

    var medication: Medication? = nil

    var status: IntakeStatus {
        get { IntakeStatus(rawValue: statusRaw) ?? .taken }
        set { statusRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        day: Date = .now,
        slotMinute: Int = 0,
        status: IntakeStatus = .taken,
        recordedAt: Date = .now
    ) {
        self.id = id
        self.day = day
        self.slotMinute = slotMinute
        self.statusRaw = status.rawValue
        self.recordedAt = recordedAt
    }
}
