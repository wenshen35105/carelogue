import Foundation
import SwiftData

/// The one visit recording in progress, owned by the app rather than by a
/// visit's card (M7 T46).
///
/// In the consulting room the phone is needed for other things while it
/// records — the journey's history, the questions to ask — so the recorder
/// outlives the screen that started it: the full-screen recorder can be
/// folded into a bar at the bottom of the app and opened again, and the
/// transcription that follows keeps going wherever the user has gone.
@MainActor
@Observable
final class VisitRecordingSession {
    static let shared = VisitRecordingSession()

    let recorder = VisitRecorder()
    /// The visit being recorded; nil when nothing is.
    private(set) var log: Log?
    /// Full-screen recorder showing (false = folded into the bar).
    var isExpanded = false

    enum Phase: Equatable {
        case transcribing
        case summarizing
    }

    /// After-recording work, per visit id.
    private(set) var phases: [UUID: Phase] = [:]
    private(set) var failures: [UUID: String] = [:]
    /// Visits whose last transcript came back with low confidence (T47).
    private(set) var lowConfidence: Set<UUID> = []

    var isRecording: Bool { log != nil }

    // MARK: - Recording

    /// Opens the recorder for a visit. With another visit already recording,
    /// that one is brought back instead — there is one microphone.
    func open(for log: Log) {
        if self.log == nil { self.log = log }
        isExpanded = true
    }

    func collapse() { isExpanded = false }

    func expand() {
        guard isRecording else { return }
        isExpanded = true
    }

    /// Throws the recording away.
    func discard() {
        recorder.cancel()
        log = nil
        isExpanded = false
    }

    /// Stops and saves onto the visit, then transcribes. A recording too
    /// short to keep ends the session too; the visit's card says why.
    func finish() {
        guard let log else { return }
        let finished = recorder.finish()
        self.log = nil
        isExpanded = false
        guard let finished else {
            failures[log.id] = String(localized: "这段录音太短了，没有保存")
            return
        }
        // Deleted while recording: nothing to attach the audio to.
        guard let context = log.modelContext, !log.isDeleted else { return }

        let artifact = Artifact(fileData: finished.data, fileName: finished.fileName, mime: Artifact.audioMime)
        context.insert(artifact)
        log.add(artifact)
        log.updatedAt = .now
        try? context.save()
        RecordingPlayer.rememberDuration(finished.duration, for: artifact.id)
        Task { await transcribeThenTidy(artifact, of: log) }
    }

    // MARK: - After recording

    func failure(for log: Log) -> String? { failures[log.id] }
    func phase(for log: Log) -> Phase? { phases[log.id] }
    func isLowConfidence(_ log: Log) -> Bool { lowConfidence.contains(log.id) }

    func setFailure(_ message: String?, for log: Log) { failures[log.id] = message }

    /// T47: redo a transcript (made before language detection, or lost). The
    /// old transcript and summary go — both came from the text being replaced.
    func retranscribe(_ artifact: Artifact, of log: Log) {
        artifact.transcript = nil
        log.visitSummaryJSON = nil
        log.updatedAt = .now
        try? log.modelContext?.save()
        Task { await transcribeThenTidy(artifact, of: log) }
    }

    private func transcribeThenTidy(_ artifact: Artifact, of log: Log) async {
        let id = log.id
        failures[id] = nil
        lowConfidence.remove(id)
        phases[id] = .transcribing
        defer { if phases[id] == .transcribing { phases[id] = nil } }

        do {
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("transcribe-\(artifact.id.uuidString).m4a")
            try artifact.fileData.write(to: url)
            defer { try? FileManager.default.removeItem(at: url) }
            let outcome = try await VisitTranscription.transcribe(
                fileURL: url, with: VisitTranscription.makeTranscriber())
            artifact.transcript = outcome.text
            log.updatedAt = .now
            try? log.modelContext?.save()
            if outcome.isLowConfidence {
                lowConfidence.insert(id)
                phases[id] = nil
                return
            }
        } catch let error as TranscriptionError {
            failures[id] = error.errorDescription
            phases[id] = nil
            return
        } catch {
            failures[id] = error.localizedDescription
            phases[id] = nil
            return
        }

        await tidyUp(log)
    }

    /// The AI half: only with AI on and consent given (the card asks for
    /// consent when the user taps 整理 themselves). A transcript that never
    /// gets summarised is still a recording the user can read.
    func tidyUp(_ log: Log) async {
        let defaults = UserDefaults.standard
        let aiEnabled = defaults.object(forKey: AISettings.enabledKey) as? Bool ?? true
        let consent = AISettings.Consent(rawValue: defaults.string(forKey: AISettings.consentKey) ?? "")
        guard aiEnabled, consent == .granted, let context = log.modelContext else { return }

        let id = log.id
        failures[id] = nil
        phases[id] = .summarizing
        defer { phases[id] = nil }
        do {
            _ = try await VisitAIService.summarize(log, in: context)
        } catch let error as VisitError {
            failures[id] = error.errorDescription
        } catch {
            failures[id] = error.localizedDescription
        }
    }
}
