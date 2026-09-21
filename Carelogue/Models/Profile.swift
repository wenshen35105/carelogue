import Foundation
import SwiftData

/// Single-row global profile. UI (T8) fetches the first row, creating one on
/// first launch if none exists yet.
@Model
final class Profile {
    var id: UUID = UUID()
    var allergies: String = ""
    var medications: String = ""
    var vaccines: String = ""
    var history: String = ""
    var updatedAt: Date = Date.now

    init(
        id: UUID = UUID(),
        allergies: String = "",
        medications: String = "",
        vaccines: String = "",
        history: String = "",
        updatedAt: Date = .now
    ) {
        self.id = id
        self.allergies = allergies
        self.medications = medications
        self.vaccines = vaccines
        self.history = history
        self.updatedAt = updatedAt
    }
}
