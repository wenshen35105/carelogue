import SwiftData

extension ModelContext {
    /// Deletes a Log together with its attachments. The `.cascade` rule on
    /// `Log.artifacts` was observed to leave orphaned Artifact rows
    /// (log == nil) behind, so attachments are removed explicitly.
    func deleteLog(_ log: Log) {
        for artifact in log.artifacts {
            delete(artifact)
        }
        delete(log)
    }
}
