import SwiftUI
import SwiftData
import UIKit

/// 白话解释 card on the Log detail page (Stitch explanation_states +
/// report_explanation). One card per Log: with several attachments a chip
/// row picks which one is shown, so only one explanation is open at a time.
struct ExplanationCard: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage(AISettings.enabledKey) private var aiEnabled = true
    @AppStorage(AISettings.consentKey) private var consentRaw = ""

    let artifacts: [Artifact]

    @State private var selectedID: UUID?
    /// Per-attachment request state; "explained" is read from the model.
    @State private var phases: [UUID: Phase] = [:]
    @State private var collapsed = false
    @State private var selectedTerm: Explanation.Term?
    @State private var notice: String?
    @State private var copied = false
    /// Artifact waiting on the consent sheet's answer.
    @State private var pendingConsent: Artifact?

    enum Phase: Equatable {
        case running
        case failed(String)
    }

    private var selected: Artifact? {
        artifacts.first { $0.id == selectedID } ?? artifacts.first
    }

    private var consent: AISettings.Consent {
        AISettings.Consent(rawValue: consentRaw) ?? .undecided
    }

    var body: some View {
        Group {
            if !aiEnabled {
                DisabledLine()
            } else if consent == .revoked {
                RevokedLine { pendingConsent = selected }
            } else if let artifact = selected {
                card(for: artifact)
            }
        }
        .sheet(item: $pendingConsent) { artifact in
            ConsentSheet(
                onAccept: {
                    consentRaw = AISettings.Consent.granted.rawValue
                    pendingConsent = nil
                    start(artifact)
                },
                onDecline: { pendingConsent = nil }
            )
        }
    }

    // MARK: - Card

    @ViewBuilder
    private func card(for artifact: Artifact) -> some View {
        let explanation = artifact.explanation
        let phase = phases[artifact.id]
        let isIdle = explanation == nil && phase == nil

        VStack(alignment: .leading, spacing: 14) {
            header(explained: explanation != nil && phase != .running)

            if artifacts.count > 1 {
                attachmentPicker
            }

            switch (phase, explanation) {
            case (.running?, _):
                GeneratingBody()
            case (.failed(let message)?, _):
                FailedBody(message: message) { start(artifact) }
            case (nil, let explanation?):
                if collapsed {
                    collapsedBody(explanation)
                } else {
                    explainedBody(explanation, artifact: artifact)
                }
            case (nil, nil):
                NotStartedBody { start(artifact) }
            }
        }
        .padding(Theme.Spacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .fill(isIdle ? Theme.accentTint.opacity(0.5) : Theme.card)
                .shadow(color: Theme.cardShadow, radius: 10, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .stroke(isIdle ? Theme.accent.opacity(0.45) : Theme.border, lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.2), value: phase)
        .animation(.easeInOut(duration: 0.2), value: collapsed)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("explain.card")
    }

    private func header(explained: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 32, height: 32)
                .background(Circle().fill(Theme.accentTint))
            // Explained: the provider pill takes the gloss's place so the
            // title never truncates.
            BilingualTitle(primary: String(localized: "白话解释（AI 生成）"),
                           secondary: explained ? nil : AppLanguage.gloss(String(localized: "AI Explained")))
                .layoutPriority(1)
            Spacer(minLength: 6)
            if explained {
                Text(verbatim: AIDisclosure.serviceName)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Capsule().stroke(Theme.accent.opacity(0.4), lineWidth: 1))
            }
        }
    }

    /// Mutually exclusive attachment chips (thumbnail + name + ✓ if explained).
    private var attachmentPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(artifacts.enumerated()), id: \.element.id) { index, artifact in
                    let isSelected = artifact.id == selected?.id
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedID = artifact.id
                            selectedTerm = nil
                            collapsed = false
                            notice = nil
                        }
                    } label: {
                        HStack(spacing: 6) {
                            AttachmentThumbnail(data: artifact.fileData, mime: artifact.mime, size: 22, cornerRadius: 5)
                            Text(artifact.fileName.isEmpty ? String(localized: "未命名附件") : artifact.fileName)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .frame(maxWidth: 120)
                            if artifact.explanation != nil {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Theme.success)
                            }
                        }
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(isSelected ? Theme.accent : Theme.inkSecondary)
                        .padding(.leading, 5)
                        .padding(.trailing, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(isSelected ? Theme.accentTint : Theme.card))
                        .overlay(Capsule().stroke(isSelected ? Theme.accent : Theme.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                    .accessibilityValue(artifact.explanation != nil ? String(localized: "已解释") : "")
                    .accessibilityIdentifier("explain.attachment.\(index)")
                }
            }
            .padding(.vertical, 1)
        }
    }

    // MARK: - Explained

    @ViewBuilder
    private func explainedBody(_ explanation: Explanation, artifact: Artifact) -> some View {
        Text(explanation.summaryPlain)
            .font(.callout)
            .foregroundStyle(Theme.inkPrimary)
            .lineSpacing(5)
            .fixedSize(horizontal: false, vertical: true)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.inset).fill(Theme.insetFill))
            .textSelection(.enabled)
            .accessibilityIdentifier("explain.summary")

        if !explanation.terms.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("术语速查 · Key Terms")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Theme.inkSecondary)
                FlowLayout(spacing: 8) {
                    ForEach(explanation.terms, id: \.self) { term in
                        TermChip(term: term, isSelected: selectedTerm == term) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedTerm = selectedTerm == term ? nil : term
                            }
                        }
                    }
                }
                if let term = selectedTerm, explanation.terms.contains(term) {
                    TermDetail(term: term) {
                        withAnimation(.easeInOut(duration: 0.2)) { selectedTerm = nil }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }

        if !explanation.questions.isEmpty {
            QuestionsBlock(questions: explanation.questions)
        }

        Label("AI 解释仅帮助理解报告，不能替代医生的诊断。", systemImage: "shield")
            .font(.caption)
            .foregroundStyle(Theme.inkSecondary)
            .fixedSize(horizontal: false, vertical: true)

        if let notice {
            Label(notice, systemImage: "clock.arrow.circlepath")
                .font(.caption)
                .foregroundStyle(Theme.accent)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("explain.notice")
        }

        HStack(spacing: 8) {
            ActionPill(title: String(localized: "重新解释"), systemImage: "arrow.clockwise") {
                start(artifact)
            }
            .accessibilityIdentifier("explain.reexplain")
            ActionPill(title: copied ? String(localized: "已复制") : String(localized: "复制"),
                       systemImage: copied ? "checkmark" : "doc.on.doc") {
                UIPasteboard.general.string = explanation.plainText
                copied = true
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    copied = false
                }
            }
            .accessibilityIdentifier("explain.copy")
            ActionPill(title: String(localized: "收起"), systemImage: "chevron.up") {
                collapsed = true
                selectedTerm = nil
            }
            .accessibilityIdentifier("explain.collapse")
        }
    }

    private func collapsedBody(_ explanation: Explanation) -> some View {
        Button {
            collapsed = false
        } label: {
            HStack(alignment: .top, spacing: 8) {
                Text(explanation.summaryPlain)
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 4)
                HStack(spacing: 2) {
                    Text("展开")
                    Image(systemName: "chevron.down")
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.accent)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("explain.expand")
    }

    // MARK: - Actions

    private func start(_ artifact: Artifact) {
        guard phases[artifact.id] != .running else { return }
        guard consent == .granted else {
            pendingConsent = artifact
            return
        }
        notice = nil
        selectedTerm = nil
        collapsed = false
        phases[artifact.id] = .running
        Task {
            do {
                let outcome = try await ExplainService.explain(artifact, in: modelContext)
                if case .throttled = outcome {
                    notice = String(localized: "5 分钟内刚解释过，先显示上次的结果")
                }
                phases[artifact.id] = nil
            } catch is CancellationError {
                phases[artifact.id] = nil
            } catch {
                phases[artifact.id] = .failed(error.localizedDescription)
            }
        }
    }
}

// MARK: - State bodies

private struct NotStartedBody: View {
    let action: () -> Void

    var body: some View {
        Text("还没有解释这份附件。点击下方按钮，会先在本机识别报告文字，再请我们选用的 AI 服务用白话讲给你听。")
            .font(.subheadline)
            .foregroundStyle(Theme.inkSecondary)
            .fixedSize(horizontal: false, vertical: true)
        Label("只发送识别出的文字 · 通常几秒内完成", systemImage: "lock")
            .font(.caption)
            .foregroundStyle(Theme.inkSecondary)
        Button(action: action) {
            Label("生成白话解释 · Explain", systemImage: "sparkles")
                .font(.body.weight(.semibold))
                .foregroundStyle(Theme.onAccent)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(RoundedRectangle(cornerRadius: 14).fill(Theme.accent))
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityIdentifier("explain.button")
    }
}

private struct GeneratingBody: View {
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 8) {
            ProgressView().controlSize(.small).tint(Theme.accent)
            BilingualTitle(primary: String(localized: "正在解释…"),
                           secondary: AppLanguage.gloss(String(localized: "Explaining")),
                           font: .subheadline.weight(.semibold))
        }
        .accessibilityIdentifier("explain.loading")
        VStack(alignment: .leading, spacing: 10) {
            ForEach([1.0, 0.92, 0.6], id: \.self) { width in
                RoundedRectangle(cornerRadius: 6)
                    .fill(Theme.border)
                    .frame(height: 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .scaleEffect(x: width, anchor: .leading)
            }
        }
        .opacity(pulse ? 0.45 : 1)
        .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: pulse)
        .onAppear { pulse = true }
        Text("在本机识别文字后只发送文字 · 通常几秒内完成")
            .font(.caption)
            .foregroundStyle(Theme.inkSecondary)
    }
}

private struct FailedBody: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Theme.warning)
                .frame(width: 36, height: 36)
                .background(Circle().fill(Theme.warning.opacity(0.12)))
            VStack(alignment: .leading, spacing: 4) {
                BilingualTitle(primary: String(localized: "无法解释，请重试"),
                               secondary: AppLanguage.gloss(String(localized: "Couldn't explain")),
                               font: .subheadline.weight(.semibold))
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("explain.errorMessage")
                Text("附件和记录都不受影响。")
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSecondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("explain.error")

        Button(action: retry) {
            Label("重试 · Retry", systemImage: "arrow.clockwise")
                .font(.body.weight(.semibold))
                .foregroundStyle(Theme.accent)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(RoundedRectangle(cornerRadius: 14).stroke(Theme.accent, lineWidth: 1.2))
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityIdentifier("explain.retry")

        NavigationLink {
            SettingsView()
        } label: {
            HStack {
                Text("检查 API Key 与网络设置")
                Spacer()
                Image(systemName: "chevron.right")
            }
            .font(.footnote)
            .foregroundStyle(Theme.inkSecondary)
        }
    }
}

/// Replaces the card when AI is switched off in Settings.
private struct DisabledLine: View {
    var body: some View {
        NavigationLink {
            SettingsView()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "lock")
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSecondary)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Theme.insetFill))
                VStack(alignment: .leading, spacing: 2) {
                    Text("AI 解释已在设置中关闭")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.inkPrimary)
                    if let gloss = AppLanguage.gloss(String(localized: "AI Explanation disabled in Settings")) {
                        Text(gloss)
                            .font(.caption)
                            .foregroundStyle(Theme.inkSecondary)
                    }
                }
                Spacer(minLength: 8)
                HStack(spacing: 2) {
                    Text("前往开启")
                    Image(systemName: "arrow.right")
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.inkSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(Theme.insetFill))
            }
            .cardSurface(padding: 14)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("explain.disabled")
    }
}

/// Replaces the card after consent was withdrawn in Settings.
private struct RevokedLine: View {
    let onReconsent: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "hand.raised")
                .font(.subheadline)
                .foregroundStyle(Theme.inkSecondary)
                .frame(width: 32, height: 32)
                .background(Circle().fill(Theme.insetFill))
            VStack(alignment: .leading, spacing: 2) {
                Text("已撤回 AI 解释同意")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.inkPrimary)
                Text("不会再发送任何报告文字")
                    .font(.caption)
                    .foregroundStyle(Theme.inkSecondary)
            }
            Spacer(minLength: 8)
            Button(action: onReconsent) {
                Text("重新同意")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Theme.accentTint))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("explain.reconsent")
        }
        .cardSurface(padding: 14)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("explain.revoked")
    }
}

// MARK: - Explained pieces

private struct TermChip: View {
    let term: Explanation.Term
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(term.original)
                .font(.footnote.weight(.medium))
                .foregroundStyle(isSelected ? Theme.accent : Theme.inkPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Capsule().fill(isSelected ? Theme.accentTint : Theme.insetFill))
                .overlay(Capsule().stroke(isSelected ? Theme.accent : Theme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("explain.term")
    }
}

private struct TermDetail: View {
    let term: Explanation.Term
    let close: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(term.original)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.inkPrimary)
                Text(term.plain)
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("explain.termDetail")
            }
            Spacer(minLength: 4)
            Button(action: close) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.inkSecondary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("关闭")
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.inset).fill(Theme.accentTint))
    }
}

private struct QuestionsBlock: View {
    let questions: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "stethoscope")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Theme.accentTint))
                VStack(alignment: .leading, spacing: 1) {
                    Text("可以问问医生")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Theme.inkPrimary)
                    if let gloss = AppLanguage.gloss(String(localized: "Questions for your Doctor")) {
                        Text(gloss)
                            .font(.caption)
                            .foregroundStyle(Theme.inkSecondary)
                    }
                }
            }
            ForEach(Array(questions.enumerated()), id: \.offset) { index, question in
                HStack(alignment: .top, spacing: 10) {
                    Text(verbatim: "\(index + 1)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(Theme.accentTint))
                    Text(question)
                        .font(.subheadline)
                        .foregroundStyle(Theme.inkPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: Theme.Radius.inset).fill(Theme.raised))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.inset).stroke(Theme.border, lineWidth: 1))
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("explain.question")
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.card - 4).fill(Theme.insetFill))
    }
}

private struct ActionPill: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.inkPrimary)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.insetFill))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
    }
}

/// DESIGN.md pressed state: slight scale-down.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

/// Wrapping row layout for the term chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let height = rows.last.map { $0.y + $0.height } ?? 0
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(ProposedViewSize(width: bounds.width, height: nil))
                subviews[index].place(at: CGPoint(x: x, y: bounds.minY + row.y),
                                      proposal: ProposedViewSize(width: min(size.width, bounds.width), height: size.height))
                x += min(size.width, bounds.width) + spacing
            }
        }
    }

    private struct Row {
        var indices: [Int] = []
        var y: CGFloat = 0
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = [Row()]
        var y: CGFloat = 0
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(ProposedViewSize(width: width, height: nil))
            let itemWidth = min(size.width, width)
            var row = rows[rows.count - 1]
            let needed = row.indices.isEmpty ? itemWidth : row.width + spacing + itemWidth
            if needed > width, !row.indices.isEmpty {
                y += row.height + spacing
                rows.append(Row(indices: [index], y: y, width: itemWidth, height: size.height))
                continue
            }
            row.indices.append(index)
            row.width = needed
            row.height = max(row.height, size.height)
            rows[rows.count - 1] = row
        }
        return rows.filter { !$0.indices.isEmpty }
    }
}
