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

    /// M7 T46: recording and the work after it belong to the app-wide
    /// session, so they carry on while the user looks elsewhere.
    private var session: VisitRecordingSession { .shared }
    @State private var showingSummary = false
    @State private var showingQuestions = false
    @State private var pendingConsent = false
    @State private var player = RecordingPlayer()
    @State private var confirmingRetranscribe = false

    private var recording: Artifact? { log.recording }
    private var phase: VisitRecordingSession.Phase? { session.phase(for: log) }
    private var isWorking: Bool { phase != nil }
    private var failure: String? { session.failure(for: log) }
    /// The last transcription came back with low confidence (M7 T47): kept,
    /// but not sent to the AI until the user asks.
    private var lowConfidence: Bool { session.isLowConfidence(log) }
    /// This visit is the one recording right now.
    private var isRecordingHere: Bool { session.log?.id == log.id }

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

            if lowConfidence && !isWorking {
                Label("转写把握不高，可能不准确——可以先听一下录音，再决定要不要整理", systemImage: "exclamationmark.bubble")
                    .font(.footnote)
                    .foregroundStyle(Theme.warning)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("recording.lowConfidence")
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
        .navigationDestination(isPresented: $showingSummary) {
            VisitSummaryView(log: log)
        }
        .navigationDestination(isPresented: $showingQuestions) {
            VisitQuestionsView(log: log)
        }
        .confirmationDialog("重新转写这段录音？", isPresented: $confirmingRetranscribe, titleVisibility: .visible) {
            Button("重新转写") {
                if let recording {
                    if player.isPlaying(recording) { player.toggle(recording) }
                    session.retranscribe(recording, of: log)
                }
            }
            .accessibilityIdentifier("recording.retranscribe.confirm")
            Button("取消", role: .cancel) {}
        } message: {
            Text("会自动判断录音的语言重新转写，并替换现有的转写和 AI 整理。")
        }
        .sheet(isPresented: $pendingConsent) {
            ConsentSheet(
                onAccept: {
                    consentRaw = AISettings.Consent.granted.rawValue
                    pendingConsent = false
                    Task { await session.tidyUp(log) }
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
                isRecordingHere ? session.expand() : start()
            } label: {
                Label(isRecordingHere ? String(localized: "正在录音 · 回到录音") : String(localized: "开始录音 · Record"),
                      systemImage: isRecordingHere ? "waveform" : "mic.fill")
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
                    timeLabel(artifact)
                    scrubber(artifact)
                }

                Menu {
                    Button {
                        share(artifact)
                    } label: {
                        Label("分享录音", systemImage: "square.and.arrow.up")
                    }
                    .accessibilityIdentifier("recording.share")
                    Button {
                        confirmingRetranscribe = true
                    } label: {
                        Label("重新转写", systemImage: "arrow.clockwise")
                    }
                    .accessibilityIdentifier("recording.retranscribe")
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(Text("更多操作"))
                .accessibilityIdentifier("recording.menu")
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

    /// Total length; "elapsed / total" once playback has started.
    private func timeLabel(_ artifact: Artifact) -> some View {
        let total = player.duration(of: artifact)
        let text = player.isLoaded(artifact)
            ? "\(player.position(of: artifact).clockString) / \(total.clockString)"
            : total.clockString
        return Text(verbatim: text)
            .font(.title3.weight(.semibold).monospacedDigit())
            .foregroundStyle(Theme.inkPrimary)
            .accessibilityIdentifier("recording.time")
    }

    /// M7 T49: the waveform doubles as the seek bar — tap or drag along it;
    /// the played part fills in.
    private func scrubber(_ artifact: Artifact) -> some View {
        let total = player.duration(of: artifact)
        let fraction = total > 0 ? player.position(of: artifact) / total : 0
        return GeometryReader { geometry in
            WaveformBars(levels: WaveformBars.shape(seed: artifact.id),
                         progress: player.isLoaded(artifact) ? fraction : nil)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let width = max(geometry.size.width, 1)
                            player.seek(artifact, to: min(max(value.location.x / width, 0), 1))
                        }
                )
        }
        .frame(height: 18)
        .accessibilityElement()
        .accessibilityLabel(Text("播放进度"))
        .accessibilityValue(Text(verbatim: "\(player.position(of: artifact).clockString) / \(total.clockString)"))
        .accessibilityAdjustableAction { direction in
            let step: TimeInterval = direction == .increment ? 15 : -15
            let target = min(max(player.position(of: artifact) + step, 0), total)
            player.seek(artifact, to: total > 0 ? target / total : 0)
        }
        .accessibilityIdentifier("recording.scrubber")
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
    /// the user's own iCloud, and never goes to the AI. T39: without an iCloud
    /// account nothing syncs, so the note must not claim iCloud storage —
    /// it says "on this device" instead, the same distinction Settings makes.
    private var privacyNote: some View {
        Label(CloudSync.isSyncing
              ? String(localized: "录音保存在你的设备与 iCloud 私有库；音频不进 AI——在这台设备上转写，只把文字送去整理")
              : String(localized: "录音只保存在这台设备上；音频不进 AI——在这台设备上转写，只把文字送去整理"),
              systemImage: "lock")
            .font(.caption)
            .foregroundStyle(Theme.inkSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("recording.privacyNote")
    }

    // MARK: - Actions

    private func start() {
        session.setFailure(nil, for: log)
        // One microphone: a recording already running elsewhere comes back
        // to the front instead (its screen names the visit).
        if session.isRecording {
            session.expand()
            return
        }
        Task {
            guard await VisitRecorder.requestPermission() else {
                session.setFailure(VisitRecorder.RecorderError.microphoneDenied.errorDescription, for: log)
                return
            }
            _ = await VisitTranscription.requestPermission()
            session.open(for: log)
        }
    }

    private func tidyUpTapped() {
        guard aiEnabled else {
            session.setFailure(VisitError.aiDisabled.errorDescription, for: log)
            return
        }
        guard AISettings.Consent(rawValue: consentRaw) == .granted else {
            pendingConsent = true
            return
        }
        Task { await session.tidyUp(log) }
    }

    /// M7 T47: the recording leaves the app only when the user sends it —
    /// AirDrop to a Mac, save to Files. The on-device transcript rides along
    /// as a .txt next to it, so a bad transcription can be checked against
    /// the audio it came from.
    private func share(_ artifact: Artifact) {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("share-\(artifact.id.uuidString)", isDirectory: true)
        do {
            try? FileManager.default.removeItem(at: folder)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let audio = folder.appendingPathComponent(artifact.fileName.isEmpty ? "visit.m4a" : artifact.fileName)
            try artifact.fileData.write(to: audio)
            var files = [audio]
            if let transcript = artifact.transcript, !transcript.isEmpty {
                let text = audio.deletingPathExtension().appendingPathExtension("txt")
                try transcript.write(to: text, atomically: true, encoding: .utf8)
                files.append(text)
            }
            SharePresenter.presentFiles(files) {
                try? FileManager.default.removeItem(at: folder)
            }
        } catch {
            try? FileManager.default.removeItem(at: folder)
            session.setFailure(error.localizedDescription, for: log)
        }
    }

}

// MARK: - Pieces

/// The static waveform on a finished recording. The bars are a stable shape
/// derived from the artifact's id — the real envelope is not kept, and a row
/// of identical bars would read as a progress bar.
struct WaveformBars: View {
    let levels: [Double]
    var tint: Color = Theme.accent
    /// Playback position 0...1 (T49): bars up to it fill in solid, the rest
    /// fade. Nil = no playback, the plain level shading.
    var progress: Double? = nil

    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .center, spacing: 3) {
                ForEach(Array(levels.enumerated()), id: \.offset) { index, level in
                    Capsule()
                        .fill(tint.opacity(opacity(at: index, level: level)))
                        .frame(height: max(3, geometry.size.height * level))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }

    private func opacity(at index: Int, level: Double) -> Double {
        guard let progress else { return 0.25 + 0.6 * level }
        let played = (Double(index) + 0.5) / Double(max(levels.count, 1)) <= progress
        return played ? 0.95 : 0.22
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
        if let known = durations[artifact.id] ?? Self.recordedDurations[artifact.id] { return known }
        // The data comes out of the store with no filename, so the type has
        // to be spelled out or the duration reads as zero.
        let measured = (try? AVAudioPlayer(data: artifact.fileData,
                                           fileTypeHint: AVFileType.m4a.rawValue))?.duration ?? 0
        durations[artifact.id] = measured
        return measured
    }

    /// Durations known from the recorder itself (T46: the session saves
    /// recordings, not the card), so a fresh recording never shows 0:00.
    private static var recordedDurations: [UUID: TimeInterval] = [:]

    static func rememberDuration(_ duration: TimeInterval, for id: UUID) {
        recordedDurations[id] = duration
    }

    /// Where playback is (or was left), for the recording currently loaded.
    private(set) var currentTime: TimeInterval = 0
    private var ticker: Timer?

    func isLoaded(_ artifact: Artifact) -> Bool { playingID == artifact.id && player != nil }

    func position(of artifact: Artifact) -> TimeInterval {
        playingID == artifact.id ? currentTime : 0
    }

    func toggle(_ artifact: Artifact) {
        if isPlaying(artifact) {
            player?.pause()
            stopTicking()
            return
        }
        guard load(artifact) else { return }
        player?.play()
        startTicking()
    }

    /// M7 T49: jump to a fraction of the recording, playing or not.
    func seek(_ artifact: Artifact, to fraction: Double) {
        guard load(artifact), let player else { return }
        player.currentTime = fraction * player.duration
        currentTime = player.currentTime
    }

    /// Makes `artifact` the loaded recording (keeping its position when it
    /// already is). False if the audio can't be read.
    @discardableResult
    private func load(_ artifact: Artifact) -> Bool {
        if playingID == artifact.id, player != nil { return true }
        player?.stop()
        stopTicking()
        // T46: while a visit records, the session stays play-and-record —
        // switching it to playback would stop the recording.
        if !VisitRecordingSession.shared.isRecording {
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
            try? AVAudioSession.sharedInstance().setActive(true)
        }
        player = try? AVAudioPlayer(data: artifact.fileData, fileTypeHint: AVFileType.m4a.rawValue)
        playingID = artifact.id
        currentTime = 0
        return player != nil
    }

    private func startTicking() {
        stopTicking()
        ticker = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.tick() }
        }
    }

    private func stopTicking() {
        ticker?.invalidate()
        ticker = nil
    }

    private func tick() {
        guard let player else { return stopTicking() }
        currentTime = player.currentTime
        // Played to the end: AVAudioPlayer rewinds itself; the bar follows.
        if !player.isPlaying { stopTicking() }
    }
}
