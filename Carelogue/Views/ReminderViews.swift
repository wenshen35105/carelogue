import SwiftUI
import UserNotifications

/// One editable visit-reminder time; the id keeps a row stable while its
/// value changes under the pickers.
struct ReminderOffsetDraft: Identifiable, Equatable {
    let id = UUID()
    var offset: VisitReminderOffset

    static func drafts(_ offsets: [VisitReminderOffset]) -> [ReminderOffsetDraft] {
        offsets.map { ReminderOffsetDraft(offset: $0) }
    }

    /// The next time worth adding after the existing ones: the built-in
    /// defaults first, then the morning of an earlier day.
    static func suggestion(after existing: [ReminderOffsetDraft]) -> VisitReminderOffset {
        let taken = Set(existing.map(\.offset))
        if let free = VisitReminderOffset.builtInDefaults.first(where: { !taken.contains($0) }) { return free }
        let day = VisitReminderOffset.dayChoices.first { day in
            !taken.contains(VisitReminderOffset(daysBefore: day, minuteOfDay: 9 * 60))
        } ?? 2
        return VisitReminderOffset(daysBefore: day, minuteOfDay: 9 * 60)
    }
}

/// 前一天 ▾  19:00 — a day menu and a time picker for one reminder (T52).
struct ReminderOffsetRow: View {
    @Binding var offset: VisitReminderOffset

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "bell")
                .font(.subheadline)
                .foregroundStyle(Theme.accent)
            Picker(selection: $offset.daysBefore) {
                ForEach(VisitReminderOffset.dayChoices, id: \.self) { day in
                    Text(VisitReminderOffset.dayLabel(day)).tag(day)
                }
            } label: {
                EmptyView()
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .tint(Theme.inkPrimary)
            .fixedSize()
            .accessibilityIdentifier("reminder.day")
            Spacer(minLength: 8)
            DatePicker("", selection: Binding(
                get: { ReminderTime.date(offset.minuteOfDay) },
                set: { offset.minuteOfDay = ReminderTime.minute(of: $0) }
            ), displayedComponents: .hourAndMinute)
            .labelsHidden()
            .accessibilityIdentifier("reminder.time")
        }
    }
}

/// Watches the notification permission and, when it is off, says how to
/// turn it back on. Shown wherever a reminder is set up.
struct NotificationPermissionNote: View {
    @State private var status: UNAuthorizationStatus?
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if status == .denied {
                VStack(alignment: .leading, spacing: 8) {
                    Label("通知权限已关闭，提醒不会弹出。", systemImage: "bell.slash")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Theme.warning)
                    Text("在「设置 › Carelogue › 通知」里打开「允许通知」后，已设好的提醒会自动生效。")
                        .font(.footnote)
                        .foregroundStyle(Theme.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("去设置开启") { Reminders.openSystemSettings() }
                        .font(.footnote.weight(.semibold))
                        .tint(Theme.accent)
                }
                .accessibilityIdentifier("reminder.permissionDenied")
            }
        }
        .task { status = await Reminders.authorizationStatus() }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { status = await Reminders.authorizationStatus() }
        }
        .onReceive(NotificationCenter.default.publisher(for: Reminders.didReplan)) { _ in
            Task { status = await Reminders.authorizationStatus() }
        }
    }
}

/// "🔔 已设提醒 · Set" on an upcoming visit (Stitch m8 journey header).
struct ReminderPill: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "bell.fill")
                .font(.caption2)
            Text("已设提醒")
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(Theme.accent)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Capsule().fill(Theme.accentTint))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("reminder.pill")
    }
}
