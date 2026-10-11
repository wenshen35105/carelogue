import CoreData
import Foundation
import SwiftData
import UIKit
import UserNotifications

// M8 T52 + T53: one local-notification system for visit and medication
// reminders. Nothing leaves the device — every reminder is a
// UNNotificationRequest scheduled here, rebuilt from the store whenever it
// changes, so editing or deleting a visit or a plan re-plans on its own.

// MARK: - Visit reminder offsets

/// "N days before the visit, at HH:MM" — one reminder time for a visit.
struct VisitReminderOffset: Codable, Hashable {
    /// 0 = on the day of the visit.
    var daysBefore: Int
    /// Minutes after midnight.
    var minuteOfDay: Int

    /// The day choices offered in the editor.
    static let dayChoices = [0, 1, 2, 3, 7]

    /// 前一天 19:00 + 当天 08:00 (M8 decision).
    static let builtInDefaults = [
        VisitReminderOffset(daysBefore: 1, minuteOfDay: 19 * 60),
        VisitReminderOffset(daysBefore: 0, minuteOfDay: 8 * 60),
    ]

    func fireDate(forVisitAt visit: Date, calendar: Calendar = .current) -> Date? {
        let visitDay = calendar.startOfDay(for: visit)
        guard let day = calendar.date(byAdding: .day, value: -daysBefore, to: visitDay) else { return nil }
        return calendar.date(byAdding: .minute, value: minuteOfDay, to: day)
    }

    static func dayLabel(_ daysBefore: Int) -> String {
        switch daysBefore {
        case 0: return String(localized: "当天")
        case 1: return String(localized: "前一天")
        case 7: return String(localized: "前一周")
        default: return String(localized: "前 \(daysBefore) 天")
        }
    }

    /// "前一天 19:00" / "1 day before, 7:00 PM".
    var label: String {
        "\(Self.dayLabel(daysBefore)) \(ReminderTime.label(minuteOfDay))"
    }

    static func encode(_ offsets: [VisitReminderOffset]) -> String? {
        guard !offsets.isEmpty, let data = try? JSONEncoder().encode(normalized(offsets)) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func decode(_ json: String?) -> [VisitReminderOffset]? {
        guard let data = json?.data(using: .utf8),
              let offsets = try? JSONDecoder().decode([VisitReminderOffset].self, from: data),
              !offsets.isEmpty else { return nil }
        return offsets
    }

    /// De-duplicated, earliest reminder first.
    static func normalized(_ offsets: [VisitReminderOffset]) -> [VisitReminderOffset] {
        Array(Set(offsets)).sorted {
            $0.daysBefore != $1.daysBefore ? $0.daysBefore > $1.daysBefore : $0.minuteOfDay < $1.minuteOfDay
        }
    }
}

/// Minutes-after-midnight helpers shared by visit and medication reminders.
enum ReminderTime {
    /// "08:00" / "8:00 AM", in the app language.
    static func label(_ minuteOfDay: Int) -> String {
        date(minuteOfDay).formatted(.dateTime.hour().minute().locale(AppLanguage.locale))
    }

    /// Today at that time — what a time-only DatePicker binds to.
    static func date(_ minuteOfDay: Int, on day: Date = .now, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .minute, value: minuteOfDay, to: calendar.startOfDay(for: day)) ?? day
    }

    static func minute(of date: Date, calendar: Calendar = .current) -> Int {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }
}

/// Where the defaults for a newly switched-on visit reminder live (Settings).
enum ReminderSettings {
    static let visitDefaultsKey = "reminders.visitDefaults"

    static var visitDefaults: [VisitReminderOffset] {
        get {
            VisitReminderOffset.decode(UserDefaults.standard.string(forKey: visitDefaultsKey))
                ?? VisitReminderOffset.builtInDefaults
        }
        set {
            UserDefaults.standard.set(VisitReminderOffset.encode(newValue), forKey: visitDefaultsKey)
        }
    }
}

extension Log {
    /// The visit's reminder times; nil = no reminder (T52).
    var reminderOffsets: [VisitReminderOffset]? {
        get { VisitReminderOffset.decode(reminderJSON) }
        set { reminderJSON = newValue.flatMap(VisitReminderOffset.encode) }
    }

    /// An upcoming visit with at least one reminder still ahead of it.
    var hasPendingReminder: Bool {
        guard kind == .encounter, let offsets = reminderOffsets else { return false }
        let now = Date.now
        return offsets.contains { ($0.fireDate(forVisitAt: occurredAt) ?? .distantPast) > now }
    }
}

// MARK: - Medication schedule

extension Medication {
    /// Today's check-in for the dose at `slotMinute`, if any (latest wins).
    func intake(on day: Date, slot slotMinute: Int, calendar: Calendar = .current) -> MedicationIntake? {
        let start = calendar.startOfDay(for: day)
        return allIntakes
            .filter { $0.slotMinute == slotMinute && calendar.isDate($0.day, inSameDayAs: start) }
            .max { $0.recordedAt < $1.recordedAt }
    }

    /// Today's doses, in time order, each with its check-in if recorded.
    func doses(on day: Date = .now) -> [(minute: Int, intake: MedicationIntake?)] {
        reminderMinutes.map { ($0, intake(on: day, slot: $0)) }
    }

    /// The first of today's doses that has no check-in yet.
    func nextOpenDose(on day: Date = .now) -> Int? {
        doses(on: day).first { $0.intake == nil }?.minute
    }

    /// When the next reminder for this plan goes off: an open dose later
    /// today, else the first dose tomorrow. Nil when paused or timeless.
    func nextReminder(after now: Date = .now, calendar: Calendar = .current) -> Date? {
        guard isActive, let first = reminderMinutes.first else { return nil }
        let nowMinute = ReminderTime.minute(of: now, calendar: calendar)
        if let later = doses(on: now).first(where: { $0.intake == nil && $0.minute > nowMinute }) {
            return ReminderTime.date(later.minute, on: now, calendar: calendar)
        }
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
        return ReminderTime.date(first, on: tomorrow, calendar: calendar)
    }

    /// Records (or replaces) the check-in for one dose.
    func record(_ status: IntakeStatus, day: Date, slot slotMinute: Int, context: ModelContext,
                calendar: Calendar = .current) {
        if let existing = intake(on: day, slot: slotMinute, calendar: calendar) {
            existing.status = status
            existing.recordedAt = .now
        } else {
            let intake = MedicationIntake(day: calendar.startOfDay(for: day), slotMinute: slotMinute, status: status)
            context.insert(intake)
            intakes = allIntakes + [intake]
            intake.medication = self
        }
        updatedAt = .now
    }

    /// Takes back today's check-in for one dose.
    func clearIntake(day: Date, slot slotMinute: Int, context: ModelContext) {
        let start = Calendar.current.startOfDay(for: day)
        let matches = allIntakes.filter {
            $0.slotMinute == slotMinute && Calendar.current.isDate($0.day, inSameDayAs: start)
        }
        intakes = allIntakes.filter { intake in !matches.contains { $0.id == intake.id } }
        for intake in matches { context.delete(intake) }
        updatedAt = .now
    }
}

extension ModelContext {
    /// Deletes a plan with its check-ins (explicitly, as with logs: nothing
    /// is left to `.cascade`).
    func deleteMedication(_ medication: Medication) {
        let intakes = medication.allIntakes
        medication.intakes = []
        for intake in intakes { delete(intake) }
        delete(medication)
    }
}

/// Today's totals across every active plan (the progress card and the home
/// entry card).
struct MedicationProgress {
    var taken = 0
    var skipped = 0
    var total = 0

    var recorded: Int { taken + skipped }
    var open: Int { max(total - recorded, 0) }
    var fraction: Double { total == 0 ? 0 : Double(recorded) / Double(total) }

    init(_ medications: [Medication], on day: Date = .now) {
        for medication in medications where medication.isActive {
            for dose in medication.doses(on: day) {
                total += 1
                switch dose.intake?.status {
                case .taken: taken += 1
                case .skipped: skipped += 1
                case nil: break
                }
            }
        }
    }
}

// MARK: - Scheduler

@MainActor
enum Reminders {
    static let visitPrefix = "visit."
    static let medicationPrefix = "med."
    static let medicationCategory = "carelogue.medication"
    static let takenAction = "carelogue.medication.taken"
    static let skipAction = "carelogue.medication.skip"

    /// iOS keeps at most 64 pending requests per app; stay under it.
    static let budget = 60
    /// Medication doses are scheduled one by one (so a dose already checked
    /// in never rings) over a rolling window, re-planned on every launch,
    /// save and check-in.
    static let maxMedicationDays = 14

    private static var center: UNUserNotificationCenter { .current() }
    private static var context: ModelContext?
    private static var observers: [NSObjectProtocol] = []
    private static var pending: Task<Void, Never>?

    /// What the last re-plan scheduled — Debug builds show it in Settings so
    /// UI tests can see reminders without waiting for them.
    private(set) static var lastPlan: [String] = []

    /// Registers the notification actions and starts re-planning after every
    /// save. Call once at app start.
    static func start(context: ModelContext) {
        guard observers.isEmpty else { return }
        self.context = context
        registerCategories()
        // Both names: ModelContext.didSave is not posted on iOS 17.0, while
        // the Core Data save underneath SwiftData always is.
        for name in [ModelContext.didSave, Notification.Name.NSManagedObjectContextDidSave] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { _ in
                Task { @MainActor in scheduleReplan() }
            })
        }
        Task { await replan() }
    }

    /// Debounced re-plan: a burst of saves collapses into one.
    static func scheduleReplan() {
        pending?.cancel()
        pending = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            await replan()
        }
    }

    // MARK: Permission

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    /// Asks once — on the first reminder the user sets up, never at launch.
    /// Returns whether reminders can be delivered.
    @discardableResult
    static func requestPermissionIfNeeded() async -> Bool {
        switch await authorizationStatus() {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
            if granted { await replan() }
            return granted
        default:
            return false
        }
    }

    static func openSystemSettings() {
        if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    // MARK: Planning

    /// Replaces every pending reminder of ours with a fresh plan.
    static func replan() async {
        guard let context else { return }
        let requests = plan(in: context, now: .now)
        let ours = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(visitPrefix) || $0.hasPrefix(medicationPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: ours)
        for request in requests {
            try? await center.add(request)
        }
        lastPlan = requests.map(\.identifier)
        NotificationCenter.default.post(name: didReplan, object: nil)
    }

    static let didReplan = Notification.Name("carelogue.reminders.didReplan")

    /// The requests to have pending right now: visit reminders first (few
    /// and one-off), medication doses filling the rest of the budget.
    static func plan(in context: ModelContext, now: Date, calendar: Calendar = .current) -> [UNNotificationRequest] {
        let visits = visitRequests(in: context, now: now, calendar: calendar)
        let doses = medicationRequests(in: context, now: now, calendar: calendar, budget: budget - visits.count)
        return visits + doses
    }

    private static func visitRequests(in context: ModelContext, now: Date, calendar: Calendar) -> [UNNotificationRequest] {
        let encounters = (try? context.fetch(FetchDescriptor<Log>(
            predicate: #Predicate { $0.kindRaw == "encounter" && $0.reminderJSON != nil }
        ))) ?? []
        var planned: [(Date, UNNotificationRequest)] = []
        for log in encounters where log.journey?.status == .active && log.occurredAt > now {
            for offset in log.reminderOffsets ?? [] {
                guard let fire = offset.fireDate(forVisitAt: log.occurredAt, calendar: calendar), fire > now else { continue }
                let content = UNMutableNotificationContent()
                content.title = String(localized: "就诊提醒 · \(log.typeDisplayName)")
                content.body = visitBody(log)
                content.sound = .default
                content.threadIdentifier = "visit"
                content.userInfo = ["log": log.id.uuidString]
                let id = "\(visitPrefix)\(log.id.uuidString).\(offset.daysBefore).\(offset.minuteOfDay)"
                planned.append((fire, UNNotificationRequest(identifier: id, content: content,
                                                            trigger: trigger(at: fire, calendar: calendar))))
            }
        }
        // Soonest first, and never more than half the budget.
        return planned.sorted { $0.0 < $1.0 }.prefix(budget / 2).map(\.1)
    }

    /// "孕期 · 10月24日 10:30 · Women's Health Clinic".
    private static func visitBody(_ log: Log) -> String {
        let place = log.location?.trimmingCharacters(in: .whitespacesAndNewlines)
        return [log.journey?.name, log.occurredAt.shortDayTime, place]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    private static func medicationRequests(in context: ModelContext, now: Date, calendar: Calendar,
                                           budget: Int) -> [UNNotificationRequest] {
        let medications = ((try? context.fetch(FetchDescriptor<Medication>())) ?? [])
            .filter { $0.isActive && !$0.reminderMinutes.isEmpty }
        let perDay = medications.reduce(0) { $0 + $1.reminderMinutes.count }
        guard perDay > 0, budget > 0 else { return [] }
        let days = min(max(budget / perDay, 1), maxMedicationDays)
        let today = calendar.startOfDay(for: now)

        var planned: [(Date, UNNotificationRequest)] = []
        for dayOffset in 0...days {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: today) else { continue }
            for medication in medications {
                for minute in medication.reminderMinutes {
                    let fire = ReminderTime.date(minute, on: day, calendar: calendar)
                    guard fire > now, medication.intake(on: day, slot: minute, calendar: calendar) == nil else { continue }
                    let content = UNMutableNotificationContent()
                    content.title = String(localized: "服药提醒 · \(medication.name)")
                    let time = ReminderTime.label(minute)
                    let dose = medication.dose.trimmingCharacters(in: .whitespacesAndNewlines)
                    content.body = dose.isEmpty ? String(localized: "按你的计划，\(time) 该服用了") : "\(dose) · \(time)"
                    content.sound = .default
                    content.threadIdentifier = "medication"
                    content.categoryIdentifier = medicationCategory
                    content.userInfo = [
                        "medication": medication.id.uuidString,
                        "day": day.timeIntervalSince1970,
                        "slot": minute,
                    ]
                    let stamp = Int(day.timeIntervalSince1970)
                    let id = "\(medicationPrefix)\(medication.id.uuidString).\(stamp).\(minute)"
                    planned.append((fire, UNNotificationRequest(identifier: id, content: content,
                                                                trigger: trigger(at: fire, calendar: calendar))))
                }
            }
        }
        return planned.sorted { $0.0 < $1.0 }.prefix(budget).map(\.1)
    }

    private static func trigger(at date: Date, calendar: Calendar) -> UNCalendarNotificationTrigger {
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
    }

    // MARK: Actions

    private static func registerCategories() {
        let taken = UNNotificationAction(identifier: takenAction, title: String(localized: "已服用"), options: [])
        let skip = UNNotificationAction(identifier: skipAction, title: String(localized: "跳过"), options: [])
        let category = UNNotificationCategory(identifier: medicationCategory, actions: [taken, skip],
                                              intentIdentifiers: [], options: [])
        center.setNotificationCategories([category])
    }

    /// A tap on 已服用 / 跳过 in a medication notification.
    static func handleMedicationAction(_ action: String, userInfo: [AnyHashable: Any], context: ModelContext) async {
        guard let idString = userInfo["medication"] as? String, let id = UUID(uuidString: idString),
              let stamp = userInfo["day"] as? TimeInterval, let slot = userInfo["slot"] as? Int else { return }
        let medication = try? context.fetch(FetchDescriptor<Medication>(predicate: #Predicate { $0.id == id })).first
        guard let medication else { return }
        medication.record(action == takenAction ? .taken : .skipped,
                          day: Date(timeIntervalSince1970: stamp), slot: slot, context: context)
        try? context.save()
        self.context = self.context ?? context
        await replan()
    }
}

/// Shows reminders while the app is open and routes taps and actions.
final class ReminderNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = ReminderNotificationDelegate()

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let action = response.actionIdentifier
        let userInfo = response.notification.request.content.userInfo
        Task { @MainActor in
            // A cold launch from an action can arrive before the store is up.
            while CarelogueApp.modelContainer == nil {
                try? await Task.sleep(for: .milliseconds(100))
            }
            if let context = CarelogueApp.modelContainer?.mainContext {
                switch action {
                case Reminders.takenAction, Reminders.skipAction:
                    await Reminders.handleMedicationAction(action, userInfo: userInfo, context: context)
                case UNNotificationDefaultActionIdentifier:
                    if userInfo["medication"] != nil {
                        AppRouter.shared.open(.medications)
                    } else if let id = (userInfo["log"] as? String).flatMap(UUID.init(uuidString:)) {
                        AppRouter.shared.open(.log(id), context: context)
                    }
                default:
                    break
                }
            }
            completionHandler()
        }
    }
}
