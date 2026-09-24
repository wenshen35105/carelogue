import SwiftUI
import SwiftData

/// 我的疑问 · My Questions (T32, Stitch "my_questions_doctor_presentation_mode").
///
/// Write what you want to ask in your own language; the English is there so
/// the phone can be handed across the desk. The list belongs to the visit and
/// needs no recording — most of it gets written the night before.
struct VisitQuestionsView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage(AISettings.enabledKey) private var aiEnabled = true
    @AppStorage(AISettings.consentKey) private var consentRaw = ""

    let log: Log

    @State private var questions = VisitQuestions()
    @State private var draft = ""
    @State private var isTranslating = false
    @State private var failure: String?
    @State private var showingPresentation = false
    @State private var pendingConsent = false
    @FocusState private var draftFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                intro
                if !questions.items.isEmpty { handOffCard }
                list
                composer

                if let failure {
                    Label(failure, systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(Theme.warning)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("questions.error")
                }

                Label("翻译只为沟通；医疗判断以医生为准", systemImage: "shield")
                    .font(.caption)
                    .foregroundStyle(Theme.inkSecondary)
            }
            .padding(Theme.Spacing.margin)
        }
        .background(Theme.background)
        .navigationTitle("我的疑问")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("questions.page")
        .onAppear { questions = log.visitQuestions }
        .fullScreenCover(isPresented: $showingPresentation) {
            DoctorHandOffView(items: questions.items)
        }
        .sheet(isPresented: $pendingConsent) {
            ConsentSheet(
                onAccept: {
                    consentRaw = AISettings.Consent.granted.rawValue
                    pendingConsent = false
                    Task { await translate() }
                },
                onDecline: { pendingConsent = false }
            )
        }
    }

    // MARK: - Blocks

    private var intro: some View {
        HStack(alignment: .top, spacing: 14) {
            IconBadge(systemName: "character.bubble", size: 40)
            VStack(alignment: .leading, spacing: 4) {
                BilingualTitle(primary: String(localized: "我的疑问"),
                               secondary: AppLanguage.gloss(String(localized: "My Questions")),
                               font: .headline)
                Text("提前梳理问诊疑问，面诊时直接展示给医生")
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .cardSurface()
    }

    private var handOffCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("DOCTOR HAND-OFF · 快速递阅", systemImage: "eye")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                Spacer(minLength: 8)
                TagPill(text: String(localized: "\(translatedCount) 题已就绪"), tinted: true)
            }
            Text("一键开启问诊大字版")
                .font(.title3.weight(.bold))
                .foregroundStyle(Theme.inkPrimary)
            Text("全屏大字模式，无干扰，方便医生一臂距离阅读")
                .font(.footnote)
                .foregroundStyle(Theme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                showingPresentation = true
            } label: {
                Label("给医生看 · Show the Doctor", systemImage: "rectangle.portrait.and.arrow.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.onAccent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(RoundedRectangle(cornerRadius: Theme.Radius.button).fill(Theme.accent))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("questions.present")
        }
        .cardSurface()
    }

    private var list: some View {
        VStack(spacing: 12) {
            ForEach(Array(questions.items.enumerated()), id: \.element.id) { index, item in
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top, spacing: 10) {
                        Text(verbatim: String(format: "%02d", index + 1))
                            .font(.subheadline.weight(.bold).monospacedDigit())
                            .foregroundStyle(Theme.accent)
                        Text(item.text)
                            .font(.body)
                            .foregroundStyle(Theme.inkPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 4)
                        Button(role: .destructive) {
                            remove(item)
                        } label: {
                            Image(systemName: "trash")
                                .font(.footnote)
                                .foregroundStyle(Theme.inkSecondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("删除问题")
                    }

                    if let english = item.translated, !english.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(verbatim: "ENGLISH NOTE")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Theme.inkSecondary)
                            Text(verbatim: "“\(english)”")
                                .font(.subheadline)
                                .foregroundStyle(Theme.inkSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: Theme.Radius.inset).fill(Theme.insetFill))
                    } else {
                        Text("还没有英文版")
                            .font(.caption)
                            .foregroundStyle(Theme.inkSecondary)
                    }
                }
                .cardSurface()
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("questions.list")
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField(text: $draft, axis: .vertical) {
                Text("想问医生什么？")
            }
            .focused($draftFocused)
            .lineLimit(1...4)
            .font(.body)
            .padding(12)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.inset).fill(Theme.insetFill))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.inset).stroke(Theme.border, lineWidth: 1))
            .accessibilityIdentifier("questions.field")

            HStack(spacing: 12) {
                Button(action: add) {
                    Label("添加新问题 · Add", systemImage: "plus.circle")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.accent)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(RoundedRectangle(cornerRadius: Theme.Radius.button).fill(Theme.accentTint))
                }
                .buttonStyle(.plain)
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier("questions.add")

                Button {
                    translateTapped()
                } label: {
                    Label(isTranslating ? String(localized: "翻译中…") : String(localized: "译成英文"),
                          systemImage: "character.book.closed")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.onAccent)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(RoundedRectangle(cornerRadius: Theme.Radius.button).fill(Theme.accent))
                }
                .buttonStyle(.plain)
                .disabled(isTranslating || !questions.needsTranslation)
                .accessibilityIdentifier("questions.translate")
            }
        }
        .cardSurface()
    }

    private var translatedCount: Int {
        questions.items.filter { !($0.translated ?? "").isEmpty }.count
    }

    // MARK: - Actions

    private func add() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        questions.items.append(VisitQuestions.Item(text: text))
        draft = ""
        draftFocused = false
        VisitAIService.save(questions, to: log, in: modelContext)
    }

    private func remove(_ item: VisitQuestions.Item) {
        questions.items.removeAll { $0.id == item.id }
        VisitAIService.save(questions, to: log, in: modelContext)
    }

    private func translateTapped() {
        failure = nil
        guard aiEnabled else {
            failure = VisitError.aiDisabled.errorDescription
            return
        }
        guard AISettings.Consent(rawValue: consentRaw) == .granted else {
            pendingConsent = true
            return
        }
        Task { await translate() }
    }

    private func translate() async {
        isTranslating = true
        defer { isTranslating = false }
        do {
            questions = try await VisitAIService.translateQuestions(for: log, in: modelContext)
        } catch let error as VisitError {
            failure = error.errorDescription
        } catch {
            failure = error.localizedDescription
        }
    }
}

/// 给医生看: the full-screen, large-type list, read at arm's length across a
/// desk. English only — it exists for the person who does not read Chinese.
struct DoctorHandOffView: View {
    @Environment(\.dismiss) private var dismiss

    let items: [VisitQuestions.Item]

    private var readable: [String] {
        items.compactMap { item in
            let english = (item.translated ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return english.isEmpty ? nil : english
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(verbatim: "PATIENT INQUIRIES FOR DR.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.headline)
                        .foregroundStyle(Theme.inkSecondary)
                }
                .accessibilityIdentifier("handoff.close")
                .accessibilityLabel("关闭")
            }
            .padding(.horizontal, Theme.Spacing.margin)
            .padding(.vertical, 16)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(Array(readable.enumerated()), id: \.offset) { index, question in
                        Text(verbatim: "\(index + 1). \(question)")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(Theme.inkPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(18)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: Theme.Radius.card).fill(Theme.insetFill))
                    }
                }
                .padding(.horizontal, Theme.Spacing.margin)
                .padding(.bottom, 24)
            }

            Text(verbatim: "For communication only; medical judgement remains with your healthcare provider.")
                .font(.footnote)
                .foregroundStyle(Theme.inkSecondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, Theme.Spacing.margin)
                .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.background)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("handoff.page")
    }
}
