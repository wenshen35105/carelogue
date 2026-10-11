import SwiftUI
import SwiftData

// M8 T53 · 用药 (Stitch m8-medications). A plan is a name, a dose and the
// times of day to be reminded; each dose can be checked in as taken or
// skipped. Reminders only — never advice (the footer says so).

// MARK: - Home entry

/// The card on the Journeys page that leads to the medication list, with
/// today's progress once there is a plan.
struct MedicationsEntryCard: View {
    let medications: [Medication]
    let action: () -> Void

    private var detail: String {
        let progress = MedicationProgress(medications)
        guard progress.total > 0 else {
            return medications.isEmpty
                ? String(localized: "添加用药计划，按时提醒")
                : String(localized: "提醒已暂停")
        }
        return String(localized: "今日已完成 \(progress.recorded)/\(progress.total) 次")
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                IconBadge(systemName: "pills", size: 36)
                VStack(alignment: .leading, spacing: 3) {
                    BilingualTitle(primary: String(localized: "用药"),
                                   secondary: AppLanguage.gloss(String(localized: "Medications")),
                                   font: .subheadline.weight(.semibold))
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(Theme.inkSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.inkSecondary)
            }
            .cardSurface(padding: 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("home.medications")
    }
}

// MARK: - List

struct MedicationListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Medication.createdAt) private var medications: [Medication]
    @Query private var journeys: [Journey]

    @State private var creating = false
    @State private var editing: Medication?
    @State private var deleting: Medication?

    private var active: [Medication] { medications.filter(\.isActive) }
    private var paused: [Medication] { medications.filter { !$0.isActive } }

    var body: some View {
        // Re-renders each minute so "下次提醒" and "已完成" follow the clock.
        TimelineView(.everyMinute) { context in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    if medications.isEmpty {
                        emptyState
                    } else {
                        if !active.isEmpty {
                            progressCard(now: context.date)
                        }
                        ForEach(active) { medication in
                            MedicationCard(medication: medication, journeyName: journeyName(for: medication),
                                           now: context.date,
                                           onEdit: { editing = medication },
                                           onDelete: { deleting = medication })
                        }
                        if !paused.isEmpty {
                            Text("已暂停 · Paused")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Theme.inkSecondary)
                                .padding(.top, 8)
                            ForEach(paused) { medication in
                                MedicationCard(medication: medication, journeyName: journeyName(for: medication),
                                               now: context.date,
                                               onEdit: { editing = medication },
                                               onDelete: { deleting = medication })
                            }
                        }
                    }
                    disclaimer
                }
                .padding(.horizontal, Theme.Spacing.margin)
                .padding(.top, 4)
                .padding(.bottom, 32)
            }
        }
        .background(Theme.background)
        .navigationTitle("用药")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    creating = true
                } label: {
                    Label("添加", systemImage: "plus")
                }
                .accessibilityIdentifier("medications.add")
            }
        }
        .sheet(isPresented: $creating) {
            MedicationEditorView(medication: nil)
        }
        .sheet(item: $editing) { medication in
            MedicationEditorView(medication: medication)
        }
        .confirmationDialog(deleting.map { String(localized: "删除「\($0.name)」？") } ?? "",
                            isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
                            titleVisibility: .visible, presenting: deleting) { medication in
            Button("删除", role: .destructive) {
                modelContext.deleteMedication(medication)
                try? modelContext.save()
            }
            Button("取消", role: .cancel) {}
        } message: { _ in
            Text("提醒和打卡记录会一起删除。")
        }
    }

    private func journeyName(for medication: Medication) -> String? {
        guard let id = medication.journeyID else { return nil }
        return journeys.first { $0.id == id }?.name
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            BilingualTitle(primary: String(localized: "用药"),
                           secondary: AppLanguage.gloss(String(localized: "Medications")),
                           font: .largeTitle.weight(.bold))
            Text("按时记录与提醒")
                .font(.subheadline)
                .foregroundStyle(Theme.inkSecondary)
        }
    }

    private func progressCard(now: Date) -> some View {
        let progress = MedicationProgress(medications, on: now)
        return HStack(spacing: 14) {
            IconBadge(systemName: "cross.vial", size: 44)
            VStack(alignment: .leading, spacing: 3) {
                BilingualTitle(primary: String(localized: "今日进度"),
                               secondary: AppLanguage.gloss(String(localized: "Today")),
                               font: .subheadline.weight(.semibold))
                Text(progress.skipped > 0
                     ? String(localized: "已服用 \(progress.taken) 次 · 跳过 \(progress.skipped) 次 · 待服用 \(progress.open) 次")
                     : String(localized: "已服用 \(progress.taken) 次 · 待服用 \(progress.open) 次"))
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            ProgressRing(fraction: progress.fraction, lineWidth: 5) {
                Text(verbatim: "\(progress.recorded)/\(progress.total)")
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.accent)
            }
            .frame(width: 48, height: 48)
        }
        .cardSurface()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("medications.progress")
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "pills")
                .font(.system(size: 32))
                .foregroundStyle(Theme.accent)
            Text("还没有用药计划")
                .font(.headline)
                .foregroundStyle(Theme.inkPrimary)
            Text("添加药名、剂量和每天的提醒时间，到点提醒你；服用后打个卡。")
                .font(.footnote)
                .foregroundStyle(Theme.inkSecondary)
                .multilineTextAlignment(.center)
            Button {
                creating = true
            } label: {
                Label("添加用药", systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.onAccent)
                    .padding(.horizontal, 18)
                    .frame(height: 44)
                    .background(RoundedRectangle(cornerRadius: Theme.Radius.button).fill(Theme.accent))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("medications.addFirst")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .cardSurface()
    }

    private var disclaimer: some View {
        VStack(spacing: 6) {
            Image(systemName: "leaf")
                .foregroundStyle(Theme.accent)
            BilingualTitle(primary: String(localized: "温和提醒"),
                           secondary: AppLanguage.gloss(String(localized: "Mindful Reminders")),
                           font: .subheadline.weight(.semibold))
            Text("只提醒你自己设置的计划，不提供任何用药或处方建议；有疑问请咨询医生或药剂师。")
                .font(.footnote)
                .foregroundStyle(Theme.inkSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(18)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.card).fill(Theme.border.opacity(0.45)))
        .padding(.top, 8)
    }
}

// MARK: - Card

private struct MedicationCard: View {
    @Environment(\.modelContext) private var modelContext

    let medication: Medication
    let journeyName: String?
    let now: Date
    let onEdit: () -> Void
    let onDelete: () -> Void

    private var doses: [(minute: Int, intake: MedicationIntake?)] { medication.doses(on: now) }
    private var openDose: Int? { medication.nextOpenDose(on: now) }
    private var isDoneToday: Bool { medication.isActive && !doses.isEmpty && openDose == nil }

    private var detailLine: String {
        let dose = medication.dose.trimmingCharacters(in: .whitespacesAndNewlines)
        let frequency = String(localized: "每天 \(medication.reminderMinutes.count) 次")
        return dose.isEmpty ? frequency : "\(dose) · \(frequency)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    if let journeyName {
                        TagPill(text: journeyName)
                    }
                    Text(medication.name)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(isDoneToday || !medication.isActive ? Theme.inkSecondary : Theme.inkPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(detailLine)
                        .font(.subheadline)
                        .foregroundStyle(Theme.inkSecondary)
                }
                Spacer(minLength: 8)
                trailingAction
            }

            if medication.isActive && doses.count > 1 {
                doseChips
            }

            HStack(spacing: 8) {
                statusPill
                Spacer(minLength: 8)
                Menu {
                    Button("编辑", systemImage: "pencil", action: onEdit)
                    if medication.isActive, let openDose {
                        Button("跳过 \(ReminderTime.label(openDose))", systemImage: "forward") {
                            record(.skipped, slot: openDose)
                        }
                    }
                    Button(medication.isActive ? String(localized: "暂停提醒") : String(localized: "恢复提醒"),
                           systemImage: medication.isActive ? "pause.circle" : "play.circle") {
                        medication.isActive.toggle()
                        medication.updatedAt = .now
                        try? modelContext.save()
                    }
                    Button("删除", systemImage: "trash", role: .destructive, action: onDelete)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.inkSecondary)
                        .frame(width: 36, height: 28)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(String(localized: "更多"))
                .accessibilityIdentifier("medication.more")
            }
        }
        .cardSurface()
        .opacity(medication.isActive ? 1 : 0.7)
        .overlay(alignment: .leading) {
            if medication.isActive && !isDoneToday {
                Capsule()
                    .fill(Theme.accent)
                    .frame(width: 3)
                    .padding(.vertical, 18)
            }
        }
    }

    @ViewBuilder
    private var trailingAction: some View {
        if medication.isActive, let openDose {
            Button {
                record(.taken, slot: openDose)
            } label: {
                Label("打卡", systemImage: "checkmark.circle")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: Theme.Radius.button).fill(Theme.accentTint))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("medication.take")
        } else if isDoneToday {
            Label("已完成", systemImage: "checkmark")
                .font(.footnote.weight(.medium))
                .foregroundStyle(Theme.inkSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: Theme.Radius.button).fill(Theme.insetFill))
                .accessibilityIdentifier("medication.done")
        }
    }

    /// One chip per dose: tap for 已服用 / 跳过 / 撤销.
    private var doseChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(doses, id: \.minute) { dose in
                    Menu {
                        Button("已服用", systemImage: "checkmark") { record(.taken, slot: dose.minute) }
                        Button("跳过", systemImage: "forward") { record(.skipped, slot: dose.minute) }
                        if dose.intake != nil {
                            Button("撤销打卡", systemImage: "arrow.uturn.backward") {
                                medication.clearIntake(day: now, slot: dose.minute, context: modelContext)
                                try? modelContext.save()
                            }
                        }
                    } label: {
                        doseChip(minute: dose.minute, status: dose.intake?.status)
                    }
                    .accessibilityIdentifier("medication.dose")
                }
            }
        }
    }

    private func doseChip(minute: Int, status: IntakeStatus?) -> some View {
        HStack(spacing: 4) {
            switch status {
            case .taken: Image(systemName: "checkmark.circle.fill")
            case .skipped: Image(systemName: "forward.circle")
            case nil: Image(systemName: "circle")
            }
            Text(ReminderTime.label(minute))
                .monospacedDigit()
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(status == .taken ? Theme.accent : Theme.inkSecondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(status == .taken ? Theme.accentTint : Theme.insetFill))
    }

    @ViewBuilder
    private var statusPill: some View {
        if !medication.isActive {
            pill(icon: "pause.circle", text: String(localized: "提醒已暂停"), tinted: false)
        } else if isDoneToday, let last = doses.compactMap(\.intake).max(by: { $0.recordedAt < $1.recordedAt }) {
            pill(icon: "checkmark.circle",
                 text: last.status == .taken
                     ? String(localized: "今日 \(last.recordedAt.formatted(.dateTime.hour().minute().locale(AppLanguage.locale))) 已服用")
                     : String(localized: "今日已跳过"),
                 tinted: false)
        } else if let next = medication.nextReminder(after: now) {
            let time = ReminderTime.label(ReminderTime.minute(of: next))
            pill(icon: "alarm",
                 text: Calendar.current.isDate(next, inSameDayAs: now)
                     ? String(localized: "下次提醒 \(time)")
                     : String(localized: "下次提醒 明天 \(time)"),
                 tinted: true)
        }
    }

    private func pill(icon: String, text: String, tinted: Bool) -> some View {
        Label(text, systemImage: icon)
            .font(.caption.weight(.medium))
            .foregroundStyle(tinted ? Theme.accent : Theme.inkSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(tinted ? Theme.accentTint : Theme.insetFill))
            .accessibilityIdentifier("medication.status")
    }

    private func record(_ status: IntakeStatus, slot: Int) {
        medication.record(status, day: now, slot: slot, context: modelContext)
        try? modelContext.save()
    }
}

// MARK: - Editor

struct MedicationEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Journey.updatedAt, order: .reverse) private var journeys: [Journey]

    let medication: Medication?

    @State private var name: String
    @State private var dose: String
    @State private var times: [TimeDraft]
    @State private var journeyID: UUID?
    @State private var isActive: Bool
    @State private var showingDeleteConfirm = false

    struct TimeDraft: Identifiable {
        let id = UUID()
        var minute: Int
    }

    init(medication: Medication?) {
        self.medication = medication
        _name = State(initialValue: medication?.name ?? "")
        _dose = State(initialValue: medication?.dose ?? "")
        _times = State(initialValue: (medication?.reminderMinutes ?? [8 * 60]).map { TimeDraft(minute: $0) })
        _journeyID = State(initialValue: medication?.journeyID)
        _isActive = State(initialValue: medication?.isActive ?? true)
    }

    /// Active journeys, plus the linked one even if it has been archived.
    private var journeyChoices: [Journey] {
        journeys.filter { $0.status == .active || $0.id == journeyID }
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            Form {
                Group {
                    Section("药品 · Medication") {
                        TextField("名称（如 叶酸片）", text: $name)
                            .accessibilityIdentifier("medication.name")
                        TextField("剂量（如 5 mg、1 片）", text: $dose)
                            .accessibilityIdentifier("medication.dose")
                    }

                    Section {
                        ForEach($times) { $draft in
                            HStack {
                                Image(systemName: draft.minute < 12 * 60 ? "sun.max" : "moon")
                                    .foregroundStyle(Theme.accent)
                                    .frame(width: 24)
                                DatePicker(Self.partOfDay(draft.minute), selection: Binding(
                                    get: { ReminderTime.date(draft.minute) },
                                    set: { draft.minute = ReminderTime.minute(of: $0) }
                                ), displayedComponents: .hourAndMinute)
                                .accessibilityIdentifier("medication.time")
                            }
                        }
                        .onDelete { times.remove(atOffsets: $0) }

                        Button {
                            times.append(TimeDraft(minute: suggestedNextMinute))
                        } label: {
                            Label("添加时间", systemImage: "plus.circle")
                        }
                        .accessibilityIdentifier("medication.addTime")
                    } header: {
                        Text("提醒时间 · Reminder times")
                    } footer: {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("每天在这些时间提醒；早晚各一次就加两个时间。左滑可删除。")
                            NotificationPermissionNote()
                        }
                    }

                    Section {
                        Picker("关联旅程", selection: $journeyID) {
                            Text("不关联").tag(UUID?.none)
                            ForEach(journeyChoices) { journey in
                                Text(journey.name).tag(UUID?.some(journey.id))
                            }
                        }
                        .accessibilityIdentifier("medication.journey")
                    } header: {
                        Text("关联旅程（可选）")
                    }

                    if medication != nil {
                        Section {
                            Toggle("提醒中", isOn: $isActive)
                                .tint(Theme.accent)
                                .accessibilityIdentifier("medication.active")
                        } footer: {
                            Text("关闭后计划保留在列表里，但不再提醒。")
                        }
                        Section {
                            Button("删除用药", role: .destructive) { showingDeleteConfirm = true }
                        }
                    }

                    Section {
                        Text("只提醒你自己设置的计划，不提供任何用药或处方建议。")
                            .font(.footnote)
                            .foregroundStyle(Theme.inkSecondary)
                    }
                }
                .listRowBackground(Theme.card)
            }
            .warmFormChrome()
            .navigationTitle(medication == nil ? String(localized: "添加用药") : String(localized: "编辑用药"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save)
                        .disabled(trimmedName.isEmpty || times.isEmpty)
                        .accessibilityIdentifier("medication.save")
                }
            }
            .confirmationDialog("删除这项用药？", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
                Button("删除", role: .destructive) {
                    if let medication {
                        modelContext.deleteMedication(medication)
                        try? modelContext.save()
                    }
                    dismiss()
                }
                Button("取消", role: .cancel) {}
            }
        }
    }

    /// 早晨 / 中午 / 下午 / 晚间 — names the row instead of repeating "time".
    static func partOfDay(_ minute: Int) -> String {
        switch minute {
        case ..<(11 * 60): return String(localized: "早晨")
        case ..<(14 * 60): return String(localized: "中午")
        case ..<(18 * 60): return String(localized: "下午")
        default: return String(localized: "晚间")
        }
    }

    /// Twelve hours after the last time, or 20:00 when that runs past midnight.
    private var suggestedNextMinute: Int {
        guard let last = times.map(\.minute).max() else { return 8 * 60 }
        let next = last + 12 * 60
        return next < 24 * 60 ? next : 20 * 60
    }

    private func save() {
        let target = medication ?? Medication()
        if medication == nil {
            modelContext.insert(target)
        }
        target.name = trimmedName
        target.dose = dose.trimmingCharacters(in: .whitespacesAndNewlines)
        target.reminderMinutes = times.map(\.minute)
        target.journeyID = journeyID
        target.isActive = isActive
        target.updatedAt = .now
        try? modelContext.save()
        // First reminder the user sets up: the moment to ask (never at launch).
        if target.isActive {
            Task { await Reminders.requestPermissionIfNeeded() }
        }
        dismiss()
    }
}

// MARK: - Progress ring

/// Apricot ring on a hairline track (today's doses, T56 journey progress).
struct ProgressRing<Label: View>: View {
    let fraction: Double
    var lineWidth: CGFloat = 6
    @ViewBuilder let label: Label

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.border, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0, min(fraction, 1)))
                .stroke(Theme.accent, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            label
        }
    }
}
