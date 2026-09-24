import SwiftUI

/// 正在录音 (T32, Stitch "active_visit_recording_sheet").
///
/// Full screen and almost empty on purpose: it is open on a table in a
/// consulting room, so it shows the one thing that matters — that it is
/// recording — and stays quiet otherwise. No marking, no counters (the Stitch
/// screen's 标记医嘱重点 / N 重点 were its own invention; design-review T32
/// note 2).
struct VisitRecordingSheet: View {
    @Environment(\.dismiss) private var dismiss

    let recorder: VisitRecorder
    let log: Log
    let onFinish: (VisitRecorder.Recording) -> Void

    @State private var failure: String?
    @State private var showingDiscardConfirm = false

    var body: some View {
        VStack(spacing: 22) {
            topBar
            reminderCard
            visitLine
            timerCard
            Spacer(minLength: 0)
            controls
            footnote
        }
        .padding(.horizontal, Theme.Spacing.margin)
        .padding(.top, 12)
        .padding(.bottom, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("recordingSheet")
        .onAppear(perform: begin)
        .confirmationDialog("丢掉这段录音？", isPresented: $showingDiscardConfirm, titleVisibility: .visible) {
            Button("丢掉", role: .destructive) {
                recorder.cancel()
                dismiss()
            }
            Button("继续录音", role: .cancel) {}
        } message: {
            Text("这段录音还没有保存，关掉就没有了。")
        }
    }

    // MARK: - Pieces

    private var topBar: some View {
        HStack {
            Button {
                showingDiscardConfirm = true
            } label: {
                Image(systemName: "chevron.down")
                    .font(.headline)
                    .foregroundStyle(Theme.inkSecondary)
            }
            .accessibilityIdentifier("recordingSheet.close")
            .accessibilityLabel("关闭")

            Spacer()

            HStack(spacing: 6) {
                Circle()
                    .fill(recorder.state == .recording ? Theme.accent : Theme.inkSecondary)
                    .frame(width: 8, height: 8)
                Text(recorder.state == .paused
                     ? String(localized: "已暂停 · Paused")
                     : String(localized: "正在录音 · Recording"))
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(recorder.state == .recording ? Theme.accent : Theme.inkSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(Theme.accentTint))
            .accessibilityIdentifier("recordingSheet.status")

            Spacer()
            Image(systemName: "mic")
                .font(.headline)
                .foregroundStyle(Theme.inkSecondary)
        }
    }

    /// Kept word for word from the design — it is the most useful sentence on
    /// the screen (design-review T32 note 5).
    private var reminderCard: some View {
        HStack(alignment: .top, spacing: 14) {
            IconBadge(systemName: "heart", size: 40)
            VStack(alignment: .leading, spacing: 6) {
                Text("记得告诉医生：我在录音，方便回家整理")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.inkPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                // English UI already read that line in English.
                if let english = AppLanguage.gloss("Let the doctor know you're recording for personal family review.") {
                    Text(verbatim: english)
                        .font(.footnote)
                        .foregroundStyle(Theme.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .cardSurface()
    }

    private var visitLine: some View {
        VStack(spacing: 6) {
            if let doctor = log.doctor, !doctor.isEmpty {
                Text(doctor)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Theme.inkPrimary)
            }
            Text(verbatim: [log.journey?.name, log.typeDisplayName].compactMap { $0 }.joined(separator: " · "))
                .font(.subheadline)
                .foregroundStyle(Theme.inkSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var timerCard: some View {
        VStack(spacing: 18) {
            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text(verbatim: recorder.elapsed.clockString)
                    .font(.system(size: 56, weight: .light).monospacedDigit())
                    .foregroundStyle(Theme.inkPrimary)
                Text(verbatim: "LIVE")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.inkSecondary)
            }
            .accessibilityIdentifier("recordingSheet.timer")

            WaveformBars(levels: displayLevels)
                .frame(height: 46)
                .animation(.easeOut(duration: 0.18), value: recorder.levels)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.card).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card).stroke(Theme.border, lineWidth: 1))
    }

    /// Always a full row of bars, so the card does not change size as levels
    /// arrive; silence simply sits low.
    private var displayLevels: [Double] {
        let measured = recorder.levels
        guard measured.count < VisitRecorder.levelWindow else { return measured }
        return Array(repeating: 0.04, count: VisitRecorder.levelWindow - measured.count) + measured
    }

    private var controls: some View {
        VStack(spacing: 14) {
            if let failure {
                Text(failure)
                    .font(.footnote)
                    .foregroundStyle(Theme.warning)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("recordingSheet.error")
            }

            HStack(spacing: 40) {
                Button {
                    recorder.state == .paused ? recorder.resume() : recorder.pause()
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: recorder.state == .paused ? "play.fill" : "pause.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(Theme.inkPrimary)
                            .frame(width: 64, height: 64)
                            .background(Circle().fill(Theme.insetFill))
                        Text(recorder.state == .paused
                             ? String(localized: "继续 · Resume")
                             : String(localized: "暂停 · Pause"))
                            .font(.caption)
                            .foregroundStyle(Theme.inkSecondary)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("recordingSheet.pause")

                Button(action: finish) {
                    VStack(spacing: 8) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(Theme.onAccent)
                            .frame(width: 88, height: 88)
                            .background(RoundedRectangle(cornerRadius: 28).fill(Theme.accent))
                        Text("完成录音 · Stop & Save")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.inkPrimary)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("recordingSheet.finish")
            }
        }
    }

    private var footnote: some View {
        Text("点完成后就在这台设备上转写；录音保存在你的设备与 iCloud 私有库，音频不进 AI")
            .font(.caption)
            .foregroundStyle(Theme.inkSecondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Actions

    private func begin() {
        guard recorder.state == .idle else { return }
        do {
            try recorder.start()
        } catch let error as VisitRecorder.RecorderError {
            failure = error.errorDescription
        } catch {
            failure = error.localizedDescription
        }
    }

    private func finish() {
        guard let finished = recorder.finish() else {
            failure = String(localized: "这段录音太短了，没有保存")
            return
        }
        onFinish(finished)
        dismiss()
    }
}
