import CoreData
import Foundation
import SwiftData
import WidgetKit

/// M8 T58: keeps the widget's snapshot (Shared/WidgetSnapshot.swift) in
/// step with the store — rebuilt after every save and on activation, and
/// written (with a widget reload) only when it actually changed.
@MainActor
enum WidgetPublisher {
    private static var context: ModelContext?
    private static var observers: [NSObjectProtocol] = []
    private static var pending: Task<Void, Never>?

    /// What was last published — Debug builds show it in Settings.
    private(set) static var current: WidgetSnapshot?

    static func start(context: ModelContext) {
        guard observers.isEmpty else { return }
        self.context = context
        // Both names, as in Reminders: ModelContext.didSave is silent on iOS 17.0.
        for name in [ModelContext.didSave, Notification.Name.NSManagedObjectContextDidSave] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { _ in
                Task { @MainActor in schedulePublish() }
            })
        }
        publish()
    }

    #if DEBUG
    /// "Widget next=<log id> latest=<log id> note=<journey id>" for UI tests.
    static var debugSummary: String {
        let snapshot = current
        return "Widget next=\(snapshot?.nextVisit?.logID.uuidString ?? "none")"
            + " latest=\(snapshot?.latest?.logID.uuidString ?? "none")"
            + " note=\(snapshot?.quickNoteJourneyID?.uuidString ?? "none")"
    }
    #endif

    static func schedulePublish() {
        pending?.cancel()
        pending = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(800))
            guard !Task.isCancelled else { return }
            publish()
        }
    }

    static func publish() {
        guard let context else { return }
        let snapshot = build(in: context, now: .now)
        current = snapshot
        guard snapshot != WidgetSnapshot.load() else { return }
        if snapshot.save() {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    static func build(in context: ModelContext, now: Date) -> WidgetSnapshot {
        let journeys = ((try? context.fetch(FetchDescriptor<Journey>())) ?? [])
        let active = journeys.filter { $0.status == .active }

        let nextVisit = active.compactMap(\.nextAppointment).min { $0.occurredAt < $1.occurredAt }
        let latest = journeys.flatMap(\.allLogs)
            .filter { $0.occurredAt <= now && !$0.isUpcoming }
            .max { $0.occurredAt < $1.occurredAt }
        let quickNoteJourney = active.max { $0.updatedAt < $1.updatedAt }

        return WidgetSnapshot(
            nextVisit: nextVisit.flatMap { item($0, title: $0.typeDisplayName, detail: $0.location) },
            latest: nextVisit == nil ? latest.flatMap { item($0, title: title(of: $0), detail: detail(of: $0)) } : nil,
            quickNoteJourneyID: quickNoteJourney?.id,
            language: AppLanguage.code
        )
    }

    private static func item(_ log: Log, title: String, detail: String?) -> WidgetSnapshot.Item? {
        guard let journey = log.journey else { return nil }
        return WidgetSnapshot.Item(logID: log.id, journeyID: journey.id, journeyName: journey.name,
                                   title: title, date: log.occurredAt,
                                   detail: detail?.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private static func title(of log: Log) -> String {
        switch log.kind {
        case .encounter: return log.type.isEmpty ? log.kind.displayName : "\(log.kind.displayName) · \(log.typeDisplayName)"
        case .quick: return log.kind.displayName
        case .measurement: return "\(log.typeDisplayName) \(log.formattedValue)"
        }
    }

    private static func detail(of log: Log) -> String? {
        switch log.kind {
        case .encounter: return log.location
        case .quick: return log.note?.split(separator: "\n").first.map(String.init)
        case .measurement: return nil
        }
    }
}
