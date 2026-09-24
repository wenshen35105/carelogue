import Foundation
import SwiftData

enum LogKind: String, Codable, CaseIterable {
    case encounter
    case quick
    case measurement
}

@Model
final class Log {
    var id: UUID = UUID()
    var kindRaw: String = LogKind.quick.rawValue
    /// Free-form sub-type, meaning depends on kind: encounter -> 面诊/体检/验血/影像/其他;
    /// quick -> 症状/情绪/备注; measurement -> 体重/血压/体温/自定义.
    var type: String = ""
    var occurredAt: Date = Date.now
    var note: String? = nil

    /// Encounter-only: location and doctor (spec's `meta` field, kept as typed
    /// optional columns instead of a JSON blob for type safety in the editor).
    var location: String? = nil
    var doctor: String? = nil

    /// Measurement-only.
    var value: Double? = nil
    var unit: String? = nil

    /// Encounter-only (T32), both JSON-encoded and both optional so the
    /// CloudKit schema stays additive:
    /// - `visitSummaryJSON`: {said_plain, key_points[], follow_ups[], model, created_at}
    ///   — what the doctor said, built from the recording's transcript.
    /// - `questionsJSON`: {items: [{id, text, translated}], updated_at}
    ///   — 我的疑问, which needs no recording and often predates the visit.
    var visitSummaryJSON: String? = nil
    var questionsJSON: String? = nil

    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    var journey: Journey? = nil

    /// Optional for CloudKit (T23) — see Journey.logs. Read through
    /// `allArtifacts`; change through `add(_:)` / `removeArtifact(id:)`.
    @Relationship(deleteRule: .cascade, inverse: \Artifact.log)
    var artifacts: [Artifact]? = []

    var allArtifacts: [Artifact] { artifacts ?? [] }

    func add(_ artifact: Artifact) {
        artifacts = allArtifacts + [artifact]
        artifact.log = self
    }

    func removeArtifact(id: UUID) {
        artifacts = allArtifacts.filter { $0.id != id }
    }

    /// Detaches every attachment and hands them back for deletion.
    @discardableResult
    func removeAllArtifacts() -> [Artifact] {
        let existing = allArtifacts
        artifacts = []
        return existing
    }

    var kind: LogKind {
        get { LogKind(rawValue: kindRaw) ?? .quick }
        set { kindRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        kind: LogKind = .quick,
        type: String = "",
        occurredAt: Date = .now,
        note: String? = nil,
        location: String? = nil,
        doctor: String? = nil,
        value: Double? = nil,
        unit: String? = nil,
        visitSummaryJSON: String? = nil,
        questionsJSON: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        journey: Journey? = nil
    ) {
        self.id = id
        self.kindRaw = kind.rawValue
        self.type = type
        self.occurredAt = occurredAt
        self.note = note
        self.location = location
        self.doctor = doctor
        self.value = value
        self.unit = unit
        self.visitSummaryJSON = visitSummaryJSON
        self.questionsJSON = questionsJSON
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.journey = journey
    }
}
