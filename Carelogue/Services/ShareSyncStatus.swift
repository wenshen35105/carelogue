import Foundation
import Observation

/// Per-journey share-sync state for the UI (T39): one observable truth for
/// "a round is in flight / the last round landed at / why the last round
/// failed", shown next to the share marker. ShareChannel writes it, views
/// read it; a device with no shared journeys simply never writes.
@MainActor
@Observable
final class ShareSyncStatus {
    static let shared = ShareSyncStatus()

    enum Phase: Equatable {
        case syncing
        case synced(Date)
        case failed(String)
    }

    /// Journey id -> latest phase. Absent = nothing ran since launch.
    private(set) var phases: [UUID: Phase] = [:]

    func update(_ phase: Phase, for journey: UUID) {
        phases[journey] = phase
    }

    /// When a share ends, its badge goes with it.
    func clear(_ journey: UUID) {
        phases[journey] = nil
    }
}
