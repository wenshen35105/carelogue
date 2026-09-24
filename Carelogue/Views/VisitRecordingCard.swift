import AVFoundation
import SwiftUI
import SwiftData

/// 面诊录音 · Visit Recording (T32, Stitch "visit_detail_with_recording_cards").
///
/// One card with three faces: nothing recorded yet, working (transcribing on
/// device, then tidying up), and a finished recording with its summary. The
/// 我的疑问 entry sits here in every state — asking questions needs no
/// recording, and often happens before the visit.
struct VisitRecordingCard: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage(AISettings.enabledKey) private var aiEnabled = true
    @AppStorage(AISettings.consentKey) private var consentRaw = ""

    let log: Log

    @State private var recorder = VisitRecorder()
    @State private var showingRecorder = false
    @State private var phase: Phase = .idle
    @State private var failure: String?
    @State private var showingSummary = false
    @State private var showingQuestions = false
    @State private var pendingConsent = false
    @State private var player = RecordingPlayer()

    enum Phase: Equatable {
        case idle
        case transcribing
        case summarizing
    }

    private var recording: Artifact? { log.recording }
    private var isWorking: Bool { phase != .idle }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            headerRow

            if isWorking {
                workingBody
            } else if let recording {
                recordedBody(recording)
            } else {
                emptyBody
            }

            if let failure {
                Label(failure, systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(Theme.warning)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("recording.error")
            }

            questionsRow
            privacyNote
        }
        .cardSurface()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("recording.card")
        .fullScreenCover(isPresented: $showingRecorder) {
            VisitRecordingSheet(recorder: recorder, log: log) { finished in
                save(finished)
            }
        }
        .navigationDestination(isPresented: $showingSummary) {
            VisitSummaryView(log: log)
        }
        .navigationDestination(isPresented: $showingQuestions) {
            VisitQuestionsView(log: log)
        }
        .sheet(isPresented: $pendingConsent) {
            ConsentSheet(
                onAccept: {
                    consentRaw = AISettings.Consent.granted.rawValue
                    pendingConsent = false
                    Task { await tidyUp() }
                },
                onDecline: { pendingConsent = false }
            )
        }
    }

    // MARK: - Faces

    /// The card's own header. The Stitch screen repeats the title inside the
    /// card; the review asked for one of them (design-review T32 note 3).
    private var headerRow: some View {
        HStack(spacing: 10) {
            IconBadge(systemName: "mic", size: 30)
            BilingualTitle(primary: String(localized: "面诊录音"),
                           secondary: AppLanguage.gloss(String(localized: "Visit Recording")),
                           font: .headline)
            Spacer(minLength: 8)
            if recording != nil && !isWorking {
                TagPill(text: String(localized: "已录音 Recorded"), tinted: true)
            }
        }
    }

    private var emptyBody: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("录下医生的话，回家慢慢整理")
                .font(.subheadline)
                .foregroundStyle(Theme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                start()
            } label: {
                Label("开始录音 · Record", systemImage: "mic.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.onAccent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(RoundedRectangle(cornerRadius: Theme.Radius.button).fill(Theme.accent))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("recording.start")
        }
    }

    private var workingBody: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ProgressView().tint(Theme.accent)
                Text(phase == .transcribing
                     ? String(localized: "正在这台设备上转写…")
                     : String(localized: "正在整理医生说的话…"))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.inkPrimary)
            }
            .accessibilityIdentifier("recording.working")

            // Stitch's skeleton block, which reads as "something is coming".
            VStack(alignment: .leading, spacing: 8) {
                ForEach([1.0, 0.92, 0.6], id: \.self) { fraction in
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Theme.insetFill)
                        .frame(height: 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .scaleEffect(x: fraction, anchor: .leading)
                }
            }
        }
    }

    private func recordedBody(_ artifact: Artifact) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                Button {
                    player.toggle(artifact)
                } label: {
                    Image(systemName: player.isPlaying(artifact) ? "pause.fill" : "play.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.onAccent)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Theme.accent))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("recording.play")

                VStack(alignment: .leading, spacing: 6) {
                    Text(verbatim: player.duration(of: artifact).clockString)
                        .font(.title3.weight(.semibold).monospacedDigit())
                        .foregroundStyle(Theme.inkPrimary)
                    WaveformBars(levels: WaveformBars.shape(seed: artifact.id))
                        .frame(height: 18)
                }
            }
            .padding(Theme.Spacing.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.inset).fill(Theme.insetFill))

            if let summary = log.visitSummary {
                Button {
                    showingSummary = true
                } label: {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.caption)
                            .foregroundStyle(Theme.accent)
                        Text(summary.saidPlain)
                            .font(.footnote)
                            .foregroundStyle(Theme.inkSecondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 4)
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Theme.inkSecondary)
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .background(RoundedRectangle(cornerRadius: Theme.Radius.inset).fill(Theme.accentTint.opacity(0.6)))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("recording.summaryLine")
            } else if artifact.transcript != nil {
                Button {
                    tidyUpTapped()
                } label: {
                    Label("整理这次面诊 · Summarize", systemImage: "sparkles")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(RoundedRectangle(cornerRadius: Theme.Radius.button).fill(Theme.accentTint))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("recording.summarize")
            }
        }
    }

    private var questionsRow: some View {
        Button {
            showingQuestions = true
        } label: {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("我的疑问（英文）· My Questions")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.accent)
                    Text("提问无需录音")
                        .font(.caption)
                        .foregroundStyle(Theme.inkSecondary)
                }
                Spacer(minLength: 8)
                if log.visitQuestions.items.isEmpty == false {
                    TagPill(text: String(localized: "\(log.visitQuestions.items.count) 条"))
                }
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.inkSecondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("recording.questions")
    }

    /// One wording everywhere (design-review T32 note 1): the audio syncs with
    /// the user's own iCloud, and never goes to the AI.
    private var privacyNote: some View {
        Label("录音保存在你的设备与 iCloud 私有库；音频不进 AI——在这台设备上转写，只把文字送去整理",
              systemImage: "lock")
            .font(.caption)
            .foregroundStyle(Theme.inkSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Actions

    private func start() {
        failure = nil
        Task {
            guard await VisitRecorder.requestPermission() else {
                failure = VisitRecorder.RecorderError.microphoneDenied.errorDescription
                return
            }
            _ = await VisitTranscription.requestPermission()
            showingRecorder = true
        }
    }

    private func save(_ finished: VisitRecorder.Recording) {
        let artifact = Artifact(fileData: finished.data, fileName: finished.fileName,
                                mime: Artifact.audioMime)
        modelContext.insert(artifact)
        log.add(artifact)
        log.updatedAt = .now
        try? modelContext.save()
        player.remember(duration: finished.duration, for: artifact)
        Task { await transcribeThenTidy(artifact) }
    }

    private func transcribeThenTidy(_ artifact: Artifact) async {
        failure = nil
        phase = .transcribing
        defer { if phase == .transcribing { phase = .idle } }

        do {
            let url = try writeTemporaryCopy(of: artifact)
            defer { try? FileManager.default.removeItem(at: url) }
            let text = try await VisitTranscription.makeTranscriber()
                .transcribe(fileURL: url, locale: VisitTranscription.preferredLocale)
            artifact.transcript = text
            log.updatedAt = .now
            try? modelContext.save()
        } catch let error as TranscriptionError {
            failure = error.errorDescription
            phase = .idle
            return
        } catch {
            failure = error.localizedDescription
            phase = .idle
            return
        }

        await tidyUp()
    }

    private func tidyUpTapped() {
        guard aiEnabled else {
            failure = VisitError.aiDisabled.errorDescription
            return
        }
        guard AISettings.Consent(rawValue: consentRaw) == .granted else {
            pendingConsent = true
            return
        }
        Task { await tidyUp() }
    }

    /// The AI half. It is a separate step on purpose: a transcript that never
    /// gets summarised is still a recording the user can read.
    private func tidyUp() async {
        guard aiEnabled, AISettings.Consent(rawValue: consentRaw) == .granted else {
            phase = .idle
            return
        }
        phase = .summarizing
        defer { phase = .idle }
        do {
            _ = try await VisitAIService.summarize(log, in: modelContext)
        } catch let error as VisitError {
            failure = error.errorDescription
        } catch {
            failure = error.localizedDescription
        }
    }

    /// The transcriber reads a file; the attachment lives in the store.
    private func writeTemporaryCopy(of artifact: Artifact) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("transcribe-\(artifact.id.uuidString).m4a")
        try artifact.fileData.write(to: url)
        return url
    }
}

// MARK: - Pieces

/// The static waveform on a finished recording. The bars are a stable shape
/// derived from the artifact's id — the real envelope is not kept, and a row
/// of identical bars would read as a progress bar.
struct WaveformBars: View {
    let levels: [Double]
    var tint: Color = Theme.accent

    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .center, spacing: 3) {
                ForEach(Array(levels.enumerated()), id: \.offset) { _, level in
                    Capsule()
                        .fill(tint.opacity(0.25 + 0.6 * level))
                        .frame(height: max(3, geometry.size.height * level))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }

    static func shape(seed: UUID, count: Int = 22) -> [Double] {
        var generator = SeededGenerator(seed: seed)
        return (0..<count).map { _ in Double.random(in: 0.25...1, using: &generator) }
    }
}

/// Deterministic per-recording, so the bars do not dance on every redraw.
private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UUID) {
        let bytes = withUnsafeBytes(of: seed.uuid) { Array($0) }
        state = bytes.prefix(8).reduce(UInt64(0)) { ($0 << 8) | UInt64($1) } | 1
    }

    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}

/// Plays a recording back from the store. Small on purpose: play, pause, and
/// the duration the card shows.
@MainActor
@Observable
final class RecordingPlayer {
    private var player: AVAudioPlayer?
    private var playingID: UUID?
    private var durations: [UUID: TimeInterval] = [:]

    func isPlaying(_ artifact: Artifact) -> Bool {
        playingID == artifact.id && player?.isPlaying == true
    }

    func duration(of artifact: Artifact) -> TimeInterval {
        if let known = durations[artifact.id] { return known }
        // The data comes out of the store with no filename, so the type has
        // to be spelled out or the duration reads as zero.
        let measured = (try? AVAudioPlayer(data: artifact.fileData,
                                           fileTypeHint: AVFileType.m4a.rawValue))?.duration ?? 0
        durations[artifact.id] = measured
        return measured
    }

    func remember(duration: TimeInterval, for artifact: Artifact) {
        durations[artifact.id] = duration
    }

    func toggle(_ artifact: Artifact) {
        if isPlaying(artifact) {
            player?.pause()
            return
        }
        if playingID == artifact.id, let player {
            player.play()
            return
        }
        player?.stop()
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        try? AVAudioSession.sharedInstance().setActive(true)
        player = try? AVAudioPlayer(data: artifact.fileData, fileTypeHint: AVFileType.m4a.rawValue)
        playingID = artifact.id
        player?.play()
    }
}
