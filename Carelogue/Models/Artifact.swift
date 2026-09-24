import Foundation
import SwiftData

@Model
final class Artifact {
    var id: UUID = UUID()
    @Attribute(.externalStorage) var fileData: Data = Data()
    var fileName: String = ""
    var mime: String = ""
    var createdAt: Date = Date.now

    /// Cached AI explanation result, JSON-encoded:
    /// {summary_plain, terms[], questions[], model, created_at}. Wired up in M3.
    var aiExplainJSON: String? = nil

    /// Audio attachments only (T32): what the phone heard, transcribed on
    /// device. The audio itself never leaves for the AI — this text is what
    /// the visit summary is built from.
    var transcript: String? = nil

    var log: Log? = nil

    init(
        id: UUID = UUID(),
        fileData: Data = Data(),
        fileName: String = "",
        mime: String = "",
        createdAt: Date = .now,
        aiExplainJSON: String? = nil,
        transcript: String? = nil,
        log: Log? = nil
    ) {
        self.id = id
        self.fileData = fileData
        self.fileName = fileName
        self.mime = mime
        self.createdAt = createdAt
        self.aiExplainJSON = aiExplainJSON
        self.transcript = transcript
        self.log = log
    }
}
