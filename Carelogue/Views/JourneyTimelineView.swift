import SwiftUI
import SwiftData

/// One row in the timeline feed: either a single non-measurement Log card,
/// or the single collapsed "measurement group" card (spec P2: measurements
/// default-collapse into one grouped card so they don't flood the feed).
private enum TimelineItem: Identifiable {
    case log(Log)
    case measurementGroup(logs: [Log], anchorDate: Date)

    var id: String {
        switch self {
        case .log(let log): return log.id.uuidString
        case .measurementGroup(_, let anchorDate): return "measurement-\(anchorDate.timeIntervalSince1970)"
        }
    }

    var sortDate: Date {
        switch self {
        case .log(let log): return log.occurredAt
        case .measurementGroup(_, let anchorDate): return anchorDate
        }
    }
}

/// P2 · Journey 时间线
struct JourneyTimelineView: View {
    let journey: Journey

    @State private var measurementExpanded = false
    @State private var creatingKind: LogKind?

    private var timelineItems: [TimelineItem] {
        let measurements = journey.logs.filter { $0.kind == .measurement }
        let others = journey.logs.filter { $0.kind != .measurement }

        var items: [TimelineItem] = others.map { .log($0) }
        if let mostRecent = measurements.map(\.occurredAt).max() {
            items.append(.measurementGroup(logs: measurements, anchorDate: mostRecent))
        }
        return items.sorted { $0.sortDate > $1.sortDate }
    }

    var body: some View {
        Group {
            if journey.logs.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(timelineItems) { item in
                        itemRow(for: item)
                            .listRowBackground(Theme.card)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .background(Theme.background)
        .navigationTitle(journey.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button("就诊", systemImage: "stethoscope") { creatingKind = .encounter }
                    Button("随手记", systemImage: "square.and.pencil") { creatingKind = .quick }
                    Button("测量", systemImage: "waveform.path.ecg") { creatingKind = .measurement }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(item: $creatingKind) { kind in
            LogEditorView(journey: journey, kind: kind)
        }
        .navigationDestination(for: Log.self) { log in
            LogDetailView(log: log)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 36))
                .foregroundStyle(Theme.inkSecondary)
            Text("还没有记录，点右上角 ＋ 开始")
                .font(.subheadline)
                .foregroundStyle(Theme.inkSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func itemRow(for item: TimelineItem) -> some View {
        switch item {
        case .log(let log):
            NavigationLink(value: log) {
                LogCard(log: log)
            }
        case .measurementGroup(let logs, _):
            VStack(spacing: 0) {
                Button {
                    withAnimation { measurementExpanded.toggle() }
                } label: {
                    MeasurementGroupCard(logs: logs, expanded: measurementExpanded)
                }
                .buttonStyle(.plain)

                if measurementExpanded {
                    ForEach(logs.sorted(by: { $0.occurredAt > $1.occurredAt })) { log in
                        NavigationLink(value: log) {
                            MeasurementRow(log: log)
                        }
                    }
                }
            }
        }
    }
}

private struct LogCard: View {
    let log: Log

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: log.kind.iconName)
                .foregroundStyle(Theme.accent)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Theme.accent.opacity(0.12)))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Theme.inkPrimary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Theme.inkSecondary)
            }
            Spacer()
        }
        .padding(.vertical, 6)
    }

    private var title: String {
        switch log.kind {
        case .encounter:
            return log.type.isEmpty ? "就诊" : log.type
        case .quick:
            let firstLine = (log.note ?? "").split(separator: "\n").first.map(String.init) ?? ""
            return firstLine.isEmpty ? (log.type.isEmpty ? "随手记" : log.type) : firstLine
        case .measurement:
            return log.type
        }
    }

    private var subtitle: String {
        let dateString = log.occurredAt.formatted(.dateTime.month(.defaultDigits).day().locale(Theme.locale))
        switch log.kind {
        case .encounter:
            let location = log.location?.isEmpty == false ? " · \(log.location!)" : ""
            return "\(dateString)\(location)"
        case .quick, .measurement:
            return dateString
        }
    }
}

private struct MeasurementGroupCard: View {
    let logs: [Log]
    let expanded: Bool

    private var mostRecent: Log? {
        logs.max(by: { $0.occurredAt < $1.occurredAt })
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "waveform.path.ecg")
                .foregroundStyle(Theme.accent)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Theme.accent.opacity(0.12)))

            VStack(alignment: .leading, spacing: 2) {
                Text("测量 ×\(logs.count)")
                    .font(.body.weight(.medium))
                    .foregroundStyle(Theme.inkPrimary)
                if let recent = mostRecent {
                    Text("最近 \(recent.formattedValue) · \(recent.occurredAt.formatted(.dateTime.month(.defaultDigits).day().locale(Theme.locale)))")
                        .font(.caption)
                        .foregroundStyle(Theme.inkSecondary)
                }
            }
            Spacer()
            Image(systemName: expanded ? "chevron.down" : "chevron.right")
                .foregroundStyle(Theme.inkSecondary)
        }
        .padding(.vertical, 6)
    }
}

private struct MeasurementRow: View {
    let log: Log

    var body: some View {
        HStack {
            Text(log.type)
                .font(.subheadline)
                .foregroundStyle(Theme.inkPrimary)
            Spacer()
            Text(log.formattedValue)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.inkPrimary)
            Text(log.occurredAt.formatted(.dateTime.month(.defaultDigits).day().hour().minute().locale(Theme.locale)))
                .font(.caption)
                .foregroundStyle(Theme.inkSecondary)
        }
        .padding(.leading, 40)
        .padding(.vertical, 4)
    }
}

private extension LogKind {
    var iconName: String {
        switch self {
        case .encounter: return "stethoscope"
        case .quick: return "square.and.pencil"
        case .measurement: return "waveform.path.ecg"
        }
    }
}

private extension Log {
    var formattedValue: String {
        guard let value else { return "--" }
        let numberString = value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
        return "\(numberString)\(unit ?? "")"
    }
}

extension LogKind: Identifiable {
    public var id: String { rawValue }
}
