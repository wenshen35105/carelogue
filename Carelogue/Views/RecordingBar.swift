import SwiftUI

/// M7 T46: where the visit recorder lives, at the root of the app. The
/// full-screen recorder is presented from here, and while it is folded away
/// a bar along the bottom keeps the recording in sight on every screen.
struct VisitRecordingHost: ViewModifier {
    @Bindable private var session = VisitRecordingSession.shared

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if session.isRecording && !session.isExpanded {
                    RecordingBar(session: session)
                        .padding(.horizontal, Theme.Spacing.margin)
                        .padding(.bottom, 8)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: session.isExpanded)
            .animation(.easeInOut(duration: 0.2), value: session.isRecording)
            .fullScreenCover(isPresented: $session.isExpanded) {
                if let log = session.log {
                    VisitRecordingSheet(session: session, log: log)
                }
            }
    }
}

extension View {
    func visitRecordingHost() -> some View {
        modifier(VisitRecordingHost())
    }
}

/// The folded recorder: still recording, time so far, pause / resume; a tap
/// anywhere else opens it again.
struct RecordingBar: View {
    let session: VisitRecordingSession

    private var recorder: VisitRecorder { session.recorder }
    private var isPaused: Bool { recorder.state == .paused }

    var body: some View {
        HStack(spacing: 12) {
            Button {
                session.expand()
            } label: {
                HStack(spacing: 10) {
                    Circle()
                        .fill(isPaused ? Theme.inkSecondary : Theme.accent)
                        .frame(width: 10, height: 10)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(isPaused ? String(localized: "已暂停 · Paused") : String(localized: "正在录音 · Recording"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.inkPrimary)
                        if let title = visitTitle {
                            Text(verbatim: title)
                                .font(.caption)
                                .foregroundStyle(Theme.inkSecondary)
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 8)
                    Text(verbatim: recorder.elapsed.clockString)
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundStyle(Theme.inkPrimary)
                    Image(systemName: "chevron.up")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.inkSecondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("recordingBar.open")

            Button {
                isPaused ? recorder.resume() : recorder.pause()
            } label: {
                Image(systemName: isPaused ? "play.fill" : "pause.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.onAccent)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Theme.accent))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isPaused ? Text("继续 · Resume") : Text("暂停 · Pause"))
            .accessibilityIdentifier("recordingBar.pause")
        }
        .padding(.leading, 16)
        .padding(.trailing, 10)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.card).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card).stroke(Theme.border, lineWidth: 1))
        .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("recordingBar")
    }

    private var visitTitle: String? {
        guard let log = session.log else { return nil }
        let parts = [log.journey?.name, log.typeDisplayName, log.doctor].compactMap { value -> String? in
            guard let value, !value.isEmpty else { return nil }
            return value
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
