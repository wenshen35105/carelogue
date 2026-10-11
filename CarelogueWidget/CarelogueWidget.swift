import SwiftUI
import WidgetKit

// M8 T58 · home-screen widget: the next visit with a countdown, else the
// latest record, else an invitation to start; the medium size adds 记一笔.
// Reads only the snapshot the app writes into the App Group.

@main
struct CarelogueWidgets: WidgetBundle {
    var body: some Widget {
        NextVisitWidget()
    }
}

struct NextVisitWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NextVisit", provider: SnapshotProvider()) { entry in
            NextVisitWidgetView(entry: entry)
                .containerBackground(WidgetPalette.background, for: .widget)
        }
        .configurationDisplayName(widgetText("下次就诊"))
        .description(widgetText("下次就诊与快速记录"))
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct NextVisitWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SnapshotEntry

    var body: some View {
        CarelogueWidgetView(snapshot: entry.snapshot, date: entry.date, isMedium: family == .systemMedium)
    }
}

struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
}

struct SnapshotProvider: TimelineProvider {
    /// The gallery preview: a made-up visit, never the user's data.
    private var sample: WidgetSnapshot {
        let journey = UUID()
        return WidgetSnapshot(
            nextVisit: .init(logID: UUID(), journeyID: journey, journeyName: widgetText("Carelogue"),
                             title: widgetText("面诊"),
                             date: Calendar.current.date(byAdding: .day, value: 3, to: .now) ?? .now, detail: nil),
            latest: nil, quickNoteJourneyID: journey)
    }

    func placeholder(in context: Context) -> SnapshotEntry {
        SnapshotEntry(date: .now, snapshot: sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        completion(SnapshotEntry(date: .now, snapshot: context.isPreview ? sample : WidgetSnapshot.load()))
    }

    /// One entry now and one at each of the next midnights, so 明天 turns
    /// into 今天 without the app having to run.
    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        let snapshot = WidgetSnapshot.load()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        var entries = [SnapshotEntry(date: .now, snapshot: snapshot)]
        for offset in 1...3 {
            if let midnight = calendar.date(byAdding: .day, value: offset, to: today) {
                entries.append(SnapshotEntry(date: midnight, snapshot: snapshot))
            }
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}
