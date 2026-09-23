import Foundation
import SwiftData

extension Notification.Name {
    /// Posted after 清空所有数据. Editors that already loaded their fields into
    /// @State listen for it and drop those values — otherwise ProfileView
    /// would write the erased profile straight back on close.
    static let carelogueDataErased = Notification.Name("carelogue.dataErased")
}

extension ModelContext {
    /// Deletes a Log together with its attachments. The `.cascade` rule on
    /// `Log.artifacts` was observed to leave orphaned Artifact rows
    /// (log == nil) behind, so attachments are removed explicitly. The Log is
    /// also removed from `journey.logs` so views observing the Journey refresh.
    func deleteLog(_ log: Log) {
        for artifact in log.removeAllArtifacts() {
            delete(artifact)
        }
        log.journey?.removeLog(id: log.id)
        delete(log)
    }

    /// What 清空所有数据 removed, so the UI can report it back.
    struct EraseSummary: Equatable {
        var journeys = 0
        var logs = 0
        var artifacts = 0
        var profiles = 0

        var isEmpty: Bool { journeys == 0 && logs == 0 && artifacts == 0 && profiles == 0 }
    }

    /// 清空所有数据 (T25): removes every Journey, Log, Artifact and Profile.
    ///
    /// Nothing here relies on `.cascade` (m2-bugs #1): each layer is fetched
    /// and deleted explicitly — attachments first, so orphaned rows left by an
    /// earlier cascade go too — and children are unhooked from their parent's
    /// array first so any view still on screen refreshes.
    @discardableResult
    func eraseAllData() -> EraseSummary {
        var summary = EraseSummary()

        for artifact in (try? fetch(FetchDescriptor<Artifact>())) ?? [] {
            artifact.log?.removeArtifact(id: artifact.id)
            delete(artifact)
            summary.artifacts += 1
        }
        for log in (try? fetch(FetchDescriptor<Log>())) ?? [] {
            log.journey?.removeLog(id: log.id)
            delete(log)
            summary.logs += 1
        }
        for journey in (try? fetch(FetchDescriptor<Journey>())) ?? [] {
            delete(journey)
            summary.journeys += 1
        }
        for profile in (try? fetch(FetchDescriptor<Profile>())) ?? [] {
            delete(profile)
            summary.profiles += 1
        }

        try? save()
        NotificationCenter.default.post(name: .carelogueDataErased, object: nil)
        return summary
    }
}
