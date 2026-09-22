import SwiftData

extension ModelContext {
    /// Deletes a Log together with its attachments. The `.cascade` rule on
    /// `Log.artifacts` was observed to leave orphaned Artifact rows
    /// (log == nil) behind, so attachments are removed explicitly. The Log is
    /// also removed from `journey.logs` so views observing the Journey refresh.
    func deleteLog(_ log: Log) {
        let artifacts = log.artifacts
        log.artifacts.removeAll()
        for artifact in artifacts {
            delete(artifact)
        }
        log.journey?.logs.removeAll { $0.id == log.id }
        delete(log)
    }
}
