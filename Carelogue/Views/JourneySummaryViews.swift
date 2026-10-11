import SwiftUI
import SwiftData

// M8 T55 / T56 · the journey header's summary chips and target progress
// (Stitch m8-journey-header), plus the sheet that edits them. Generic for
// every journey; a template only suggests names.

// MARK: - Chips

/// 预产期 2026-11-20 · 血型 O+ · 产科医生 Dr. Chen — the target first, then
/// the summary items. Tapping any chip opens the editor.
struct JourneySummaryChips: View {
    let journey: Journey
    let onEdit: () -> Void

    var body: some View {
        let items = journey.summaryItems
        if journey.targetDate != nil || !items.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    if let target = journey.targetDate {
                        chip(icon: "calendar",
                             key: journey.targetLabel ?? String(localized: "目标日"),
                             value: target.numericDate)
                    }
                    ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                        chip(icon: nil, key: item.key, value: item.value)
                    }
                }
                .padding(.vertical, 1)
            }
        }
    }

    private func chip(icon: String?, key: String, value: String) -> some View {
        Button(action: onEdit) {
            HStack(spacing: 5) {
                if let icon {
                    Image(systemName: icon)
                        .foregroundStyle(Theme.accent)
                }
                Text(key)
                    .foregroundStyle(Theme.inkSecondary)
                Text(value)
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.inkPrimary)
            }
            .font(.footnote)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Capsule().fill(Theme.card))
            .overlay(Capsule().stroke(Theme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("journey.chip")
    }
}

// MARK: - Progress

/// Ring + "还剩 98 天 · 第 26 周" toward the journey's target day (T56).
struct JourneyProgressCard: View {
    let journey: Journey
    let onEdit: () -> Void

    var body: some View {
        if let progress = journey.progress() {
            Button(action: onEdit) {
                HStack(spacing: 18) {
                    ProgressRing(fraction: progress.fraction, lineWidth: 8) {
                        VStack(spacing: 0) {
                            Text(verbatim: "\(progress.percent)%")
                                .font(.title3.weight(.bold))
                                .monospacedDigit()
                                .foregroundStyle(Theme.inkPrimary)
                            Text("进度")
                                .font(.caption2)
                                .foregroundStyle(Theme.inkSecondary)
                        }
                    }
                    .frame(width: 84, height: 84)

                    VStack(alignment: .leading, spacing: 5) {
                        if let week = progress.week, progress.daysLeft >= 0 {
                            Text("第 \(week) 周")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.accent)
                        }
                        Text(remainingText(progress))
                            .font(.title2.weight(.bold))
                            .foregroundStyle(Theme.inkPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Text("\(journey.targetLabel ?? String(localized: "目标日")) · \(progress.target.numericDate)")
                            .font(.footnote)
                            .foregroundStyle(Theme.inkSecondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .cardSurface(padding: 18)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("journey.progress")
        }
    }

    private func remainingText(_ progress: JourneyProgress) -> String {
        switch progress.daysLeft {
        case 0: return String(localized: "就是今天")
        case 1...: return String(localized: "还剩 \(progress.daysLeft) 天")
        default: return String(localized: "已过 \(-progress.daysLeft) 天")
        }
    }
}

// MARK: - Editor

struct JourneySummaryEditor: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let journey: Journey

    @State private var hasTarget: Bool
    @State private var targetLabel: String
    @State private var targetDate: Date
    @State private var startDate: Date
    /// Once the user picks a start by hand, a new target no longer moves it.
    @State private var startEdited: Bool
    @State private var items: [ItemDraft]

    struct ItemDraft: Identifiable {
        let id = UUID()
        var key: String
        var value: String
    }

    init(journey: Journey) {
        self.journey = journey
        let template = journey.template
        let target = journey.targetDate ?? Calendar.current.date(byAdding: .month, value: 1, to: .now) ?? .now
        _hasTarget = State(initialValue: journey.targetDate != nil)
        _targetLabel = State(initialValue: journey.targetLabel ?? template.targetLabelSuggestions.first ?? "")
        _targetDate = State(initialValue: target)
        _startDate = State(initialValue: journey.progressStartDate
            ?? template.suggestedStart(forTarget: target)
            ?? journey.createdAt)
        _startEdited = State(initialValue: journey.progressStartDate != nil && journey.targetDate != nil)
        _items = State(initialValue: journey.summaryItems.map { ItemDraft(key: $0.key, value: $0.value) })
    }

    private var template: JourneyTemplate { journey.template }

    /// Template keys not on the list yet, offered as one-tap slots.
    private var missingKeys: [String] {
        let present = Set(items.map { $0.key.trimmingCharacters(in: .whitespacesAndNewlines) })
        return template.summaryKeySuggestions.filter { !present.contains($0) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Group {
                    targetSection
                    itemsSection
                }
                .listRowBackground(Theme.card)
            }
            .warmFormChrome()
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(String(localized: "概要与目标日"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save)
                        .accessibilityIdentifier("summary.save")
                }
            }
        }
    }

    @ViewBuilder
    private var targetSection: some View {
        Section {
            Toggle("设置目标日", isOn: $hasTarget)
                .tint(Theme.accent)
                .accessibilityIdentifier("summary.targetToggle")
            if hasTarget {
                TextField("名称（如 预产期、手术日）", text: $targetLabel)
                    .accessibilityIdentifier("summary.targetLabel")
                if template.targetLabelSuggestions.count > 1 || targetLabel.isEmpty {
                    suggestionChips(template.targetLabelSuggestions) { targetLabel = $0 }
                }
                DatePicker("日期", selection: $targetDate, displayedComponents: .date)
                    .accessibilityIdentifier("summary.targetDate")
                    .onChange(of: targetDate) { _, target in
                        guard !startEdited, let start = template.suggestedStart(forTarget: target) else { return }
                        startDate = start
                    }
                DatePicker("进度起点", selection: Binding(
                    get: { startDate },
                    set: { startDate = $0; startEdited = true }
                ), in: ...targetDate, displayedComponents: .date)
                .accessibilityIdentifier("summary.startDate")
            }
        } header: {
            Text("目标日 · Target date")
        } footer: {
            if hasTarget {
                Text(template.suggestedStart(forTarget: targetDate) != nil
                     ? String(localized: "头部会显示从起点走到目标日的进度。孕期的起点按预产期前 40 周推算，可以改。")
                     : String(localized: "头部会显示从起点走到目标日的进度，起点默认是旅程创建那天。"))
            }
        }
    }

    @ViewBuilder
    private var itemsSection: some View {
        Section {
            ForEach($items) { $item in
                HStack(spacing: 10) {
                    TextField("项目", text: $item.key)
                        .frame(maxWidth: 120)
                        .foregroundStyle(Theme.inkSecondary)
                        .accessibilityIdentifier("summary.itemKey")
                    Divider()
                    TextField("内容", text: $item.value)
                        .accessibilityIdentifier("summary.itemValue")
                }
            }
            .onDelete { items.remove(atOffsets: $0) }

            if !missingKeys.isEmpty {
                suggestionChips(missingKeys.map { "+ \($0)" }) { label in
                    items.append(ItemDraft(key: String(label.dropFirst(2)), value: ""))
                }
            }

            Button {
                items.append(ItemDraft(key: "", value: ""))
            } label: {
                Label("添加一项", systemImage: "plus.circle")
            }
            .accessibilityIdentifier("summary.addItem")
        } header: {
            Text("概要 · Summary")
        } footer: {
            Text("显示在旅程标题下方，比如血型、主治医生。没填内容的项不会显示。左滑可删除。")
        }
    }

    private func suggestionChips(_ options: [String], pick: @escaping (String) -> Void) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(options, id: \.self) { option in
                    ChipButton(title: option, isSelected: false) { pick(option) }
                        .accessibilityIdentifier("summary.suggestion")
                }
            }
            .padding(.vertical, 2)
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
    }

    private func save() {
        if hasTarget {
            let label = targetLabel.trimmingCharacters(in: .whitespacesAndNewlines)
            journey.targetDate = Calendar.current.startOfDay(for: targetDate)
            journey.targetLabel = label.isEmpty ? nil : label
            let start = Calendar.current.startOfDay(for: startDate)
            // Only stored when it differs from the default (creation day).
            journey.progressStartDate = Calendar.current.isDate(start, inSameDayAs: journey.createdAt) ? nil : start
        } else {
            journey.targetDate = nil
            journey.targetLabel = nil
            journey.progressStartDate = nil
        }
        journey.summaryItems = items.map { JourneySummaryItem(key: $0.key, value: $0.value) }
        journey.updatedAt = .now
        try? modelContext.save()
        dismiss()
    }
}
