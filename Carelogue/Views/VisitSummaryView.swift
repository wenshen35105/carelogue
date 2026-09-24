import SwiftUI
import SwiftData

/// 面诊总结 · Visit Summary (T32, Stitch "visit_summary_what_doctor_said").
///
/// Three blocks in the order the design puts them: what the doctor said, the
/// concrete things to remember, and what is still worth asking. The summary
/// is saved on the visit as soon as it is made, so there is no 存入病历 button
/// (design-review T32 note 4) — only 重新整理 and 复制要点.
struct VisitSummaryView: View {
    @Environment(\.modelContext) private var modelContext

    let log: Log

    @State private var isWorking = false
    @State private var failure: String?
    @State private var copied = false

    private var summary: VisitSummary? { log.visitSummary }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                metaLine

                if let summary {
                    saidBlock(summary)
                    if !summary.keyPoints.isEmpty { keyPointsBlock(summary.keyPoints) }
                    if !summary.followUps.isEmpty { followUpsBlock(summary.followUps) }
                    disclaimer
                    actions
                } else {
                    emptyState
                }

                if let failure {
                    Label(failure, systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(Theme.warning)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("summary.error")
                }
            }
            .padding(Theme.Spacing.margin)
        }
        .background(Theme.background)
        .navigationTitle("面诊总结")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("summary.page")
    }

    // MARK: - Blocks

    private var metaLine: some View {
        HStack(spacing: 8) {
            Image(systemName: "calendar")
                .font(.caption)
            Text(verbatim: [
                log.occurredAt.formatted(.dateTime.month().day().locale(AppLanguage.locale)),
                log.typeDisplayName,
                log.doctor,
            ].compactMap { $0 }.joined(separator: " · "))
        }
        .font(.subheadline)
        .foregroundStyle(Theme.inkSecondary)
    }

    private func saidBlock(_ summary: VisitSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                IconBadge(systemName: "text.alignleft", size: 30)
                BilingualTitle(primary: String(localized: "医生说了什么"),
                               secondary: AppLanguage.gloss(String(localized: "What the doctor said")),
                               font: .headline)
                Spacer(minLength: 8)
                if isWorking { ProgressView().tint(Theme.accent) }
            }
            Text(summary.saidPlain)
                .font(.body)
                .foregroundStyle(Theme.inkPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(Theme.Spacing.cardPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: Theme.Radius.inset).fill(Theme.insetFill))
                .accessibilityIdentifier("summary.said")
        }
        .cardSurface()
    }

    private func keyPointsBlock(_ points: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                IconBadge(systemName: "checklist", size: 30)
                BilingualTitle(primary: String(localized: "关键要点"),
                               secondary: AppLanguage.gloss(String(localized: "Key Points")),
                               font: .headline)
                Spacer(minLength: 8)
                TagPill(text: String(localized: "\(points.count) 项"))
            }
            VStack(spacing: 8) {
                ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "checkmark.circle")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Theme.accent)
                            .padding(.top, 2)
                        Text(point)
                            .font(.subheadline)
                            .foregroundStyle(Theme.inkPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: Theme.Radius.inset).fill(Theme.insetFill))
                }
            }
            .accessibilityElement(children: .contain)
        .accessibilityIdentifier("summary.keyPoints")
        }
        .cardSurface()
    }

    private func followUpsBlock(_ questions: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                IconBadge(systemName: "questionmark.bubble", size: 30)
                BilingualTitle(primary: String(localized: "可以再问"),
                               secondary: AppLanguage.gloss(String(localized: "Follow-ups")),
                               font: .headline)
            }
            VStack(spacing: 8) {
                ForEach(Array(questions.enumerated()), id: \.offset) { _, question in
                    Text(question)
                        .font(.subheadline)
                        .foregroundStyle(Theme.inkPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: Theme.Radius.inset).fill(Theme.insetFill))
                }
            }
            .accessibilityElement(children: .contain)
        .accessibilityIdentifier("summary.followUps")
        }
        .cardSurface()
    }

    private var disclaimer: some View {
        Label("AI 整理，可能有遗漏；请以医生原话与病历为准", systemImage: "info.circle")
            .font(.caption)
            .foregroundStyle(Theme.inkSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var actions: some View {
        HStack(spacing: 12) {
            Button {
                Task { await regenerate() }
            } label: {
                Label("重新整理", systemImage: "arrow.clockwise")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.inkPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(RoundedRectangle(cornerRadius: Theme.Radius.button).fill(Theme.insetFill))
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.button).stroke(Theme.border, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .disabled(isWorking)
            .accessibilityIdentifier("summary.regenerate")

            Button {
                UIPasteboard.general.string = summary?.plainText
                copied = true
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    copied = false
                }
            } label: {
                Label(copied ? String(localized: "已复制") : String(localized: "复制要点"),
                      systemImage: copied ? "checkmark" : "doc.on.doc")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.onAccent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(RoundedRectangle(cornerRadius: Theme.Radius.button).fill(Theme.accent))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("summary.copy")
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("这次面诊还没有整理过")
                .font(.headline)
                .foregroundStyle(Theme.inkPrimary)
            Text("录音转写好之后，可以让 AI 把医生说的话整理成要点。只有文字会送出去，音频不会。")
                .font(.subheadline)
                .foregroundStyle(Theme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                Task { await regenerate() }
            } label: {
                Label("开始整理", systemImage: "sparkles")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.onAccent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(RoundedRectangle(cornerRadius: Theme.Radius.button).fill(Theme.accent))
            }
            .buttonStyle(.plain)
            .disabled(isWorking || log.recording?.transcript == nil)
            .accessibilityIdentifier("summary.start")
        }
        .cardSurface()
    }

    private func regenerate() async {
        failure = nil
        isWorking = true
        defer { isWorking = false }
        do {
            _ = try await VisitAIService.summarize(log, in: modelContext)
        } catch let error as VisitError {
            failure = error.errorDescription
        } catch {
            failure = error.localizedDescription
        }
    }
}
