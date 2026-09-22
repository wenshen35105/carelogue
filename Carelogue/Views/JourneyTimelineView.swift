import SwiftUI
import SwiftData

/// One row in the timeline feed: either a single non-measurement Log card,
/// or the single collapsed "measurement group" card (spec P2: measurements
/// default-collapse into one grouped card so they don't flood the feed).
private enum TimelineItem: Identifiable {
    case log(Log)
    case measurementGroup(logs: [Log], anchorDate: Date)
    /// Filter chips + "图表" entry shown under the expanded group header.
    case measurementControls(anchorDate: Date)
    case measurementRow(Log)

    var id: String {
        switch self {
        case .log(let log): return log.id.uuidString
        case .measurementGroup(_, let anchorDate): return "measurement-group-\(anchorDate.timeIntervalSince1970)"
        case .measurementControls: return "measurement-controls"
        case .measurementRow(let log): return "measurement-row-\(log.id.uuidString)"
        }
    }

    var sortDate: Date {
        switch self {
        case .log(let log): return log.occurredAt
        case .measurementGroup(_, let anchorDate): return anchorDate
        case .measurementControls(let anchorDate): return anchorDate
        case .measurementRow(let log): return log.occurredAt
        }
    }
}

/// P2 · Journey 时间线
struct JourneyTimelineView: View {
    @Environment(\.modelContext) private var modelContext

    let journey: Journey

    @State private var measurementExpanded = false
    @State private var creatingKind: LogKind?
    /// Selected measurement type chip; nil = 全部.
    @State private var measurementFilter: String?
    @State private var editingMeasurement: Log?
    @State private var showingChart = false

    private var measurements: [Log] {
        journey.logs.filter { $0.kind == .measurement }
    }

    /// Distinct measurement types, most-recorded first.
    private var measurementTypes: [(name: String, count: Int)] {
        let counts = Dictionary(grouping: measurements, by: \.type).mapValues(\.count)
        return counts.map { (name: $0.key, count: $0.value) }
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0.name < $1.name }
    }

    /// Ignores a stale selection (e.g. the last 血压 entry was deleted).
    private var effectiveMeasurementFilter: String? {
        guard let measurementFilter, measurementTypes.contains(where: { $0.name == measurementFilter }) else { return nil }
        return measurementFilter
    }

    private var timelineItems: [TimelineItem] {
        let measurements = self.measurements
        let others = journey.logs.filter { $0.kind != .measurement }

        var items: [TimelineItem] = others.map { .log($0) }
        if let mostRecent = measurements.map(\.occurredAt).max() {
            items.append(.measurementGroup(logs: measurements, anchorDate: mostRecent))
        }
        // Reverse-chronological, so upcoming (future-dated) encounters sit on top.
        items.sort { $0.sortDate > $1.sortDate }

        // Splice the expanded rows in right after the group header, as
        // separate top-level list items so each one gets its own swipe area.
        if measurementExpanded, let groupIndex = items.firstIndex(where: {
            if case .measurementGroup = $0 { return true } else { return false }
        }) {
            let filter = effectiveMeasurementFilter
            let sorted = measurements
                .filter { filter == nil || $0.type == filter }
                .sorted { $0.occurredAt > $1.occurredAt }
            let expanded: [TimelineItem] = [.measurementControls(anchorDate: items[groupIndex].sortDate)]
                + sorted.map { .measurementRow($0) }
            items.insert(contentsOf: expanded, at: groupIndex + 1)
        }
        return items
    }

    var body: some View {
        List {
            header
                .canvasListRow(top: 4, bottom: 20)

            if journey.logs.isEmpty {
                emptyState
                    .canvasListRow()
            } else {
                let items = timelineItems
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    itemRow(for: item, isLast: index == items.count - 1)
                        .canvasListRow(bottom: 0)
                }

                HStack(spacing: 6) {
                    Image(systemName: "leaf")
                    Text("温和记录，陪你走好每一步")
                }
                    .font(.caption)
                    .foregroundStyle(Theme.inkSecondary)
                    .frame(maxWidth: .infinity)
                    .canvasListRow(top: 12, bottom: 96) // clear the FAB
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle(journey.name)
        .navigationBarTitleDisplayMode(.large)
        .overlay(alignment: .bottomTrailing) {
            addButton
        }
        .sheet(item: $creatingKind) { kind in
            LogEditorView(journey: journey, kind: kind)
        }
        .sheet(item: $editingMeasurement) { log in
            LogEditorView(journey: journey, kind: .measurement, existingLog: log)
        }
        .sheet(isPresented: $showingChart) {
            MeasurementChartView(journey: journey, initialType: effectiveMeasurementFilter)
        }
        .navigationDestination(for: Log.self) { log in
            LogDetailView(log: log)
        }
    }

    // MARK: - Header / empty / FAB

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                if let label = journey.template.englishLabel {
                    Text(label)
                        .font(.caption.weight(.semibold))
                        .tracking(0.8)
                        .foregroundStyle(Theme.accent)
                }
                StatusPill(status: journey.status)
            }
            Text("\(journey.template.displayName) · 始于 \(journey.createdAt.yearMonth) · 共 \(journey.logs.count) 条记录")
                .font(.footnote)
                .foregroundStyle(Theme.inkSecondary)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 32))
                .foregroundStyle(Theme.inkSecondary)
            Text("还没有记录，点右下角 ＋ 开始")
                .font(.subheadline)
                .foregroundStyle(Theme.inkSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }

    private var addButton: some View {
        Menu {
            Button(LogKind.encounter.displayName, systemImage: LogKind.encounter.iconName) { creatingKind = .encounter }
            Button(LogKind.quick.displayName, systemImage: LogKind.quick.iconName) { creatingKind = .quick }
            Button(LogKind.measurement.displayName, systemImage: LogKind.measurement.iconName) { creatingKind = .measurement }
        } label: {
            Image(systemName: "plus")
                .font(.title2.weight(.medium))
                .foregroundStyle(Theme.onAccent)
                .frame(width: 58, height: 58)
                .background(Circle().fill(Theme.accent))
                .shadow(color: Theme.accent.opacity(0.35), radius: 10, y: 5)
        }
        .accessibilityLabel("新建记录")
        .padding(.trailing, Theme.Spacing.margin)
        .padding(.bottom, 12)
    }

    // MARK: - Rows

    @ViewBuilder
    private func itemRow(for item: TimelineItem, isLast: Bool) -> some View {
        switch item {
        case .log(let log):
            TimelineRail(marker: log.isUpcoming ? .upcoming : (log.kind == .encounter ? .accent : .muted), isLast: isLast) {
                linkedCard(log) {
                    if log.isUpcoming {
                        UpcomingCard(log: log)
                    } else {
                        LogCard(log: log)
                    }
                }
            }
            .swipeActions(edge: .trailing) {
                Button("删除", role: .destructive) { deleteLog(log) }
            }
        case .measurementGroup(let logs, _):
            TimelineRail(marker: .muted, isLast: isLast && !measurementExpanded) {
                Button {
                    withAnimation { measurementExpanded.toggle() }
                } label: {
                    MeasurementGroupCard(logs: logs, expanded: measurementExpanded)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("measurement.group")
            }
        case .measurementControls:
            TimelineRail(marker: .none, isLast: isLast) {
                measurementControls
            }
        case .measurementRow(let log):
            // Straight to the editor (which also has 删除): 展开 -> row is
            // 2 taps from the timeline to edit or delete a measurement.
            TimelineRail(marker: .none, isLast: isLast) {
                Button { editingMeasurement = log } label: {
                    MeasurementRow(log: log)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("measurement.row")
            }
            .swipeActions(edge: .trailing) {
                Button("删除", role: .destructive) { deleteLog(log) }
            }
        }
    }

    private var measurementControls: some View {
        HStack(spacing: 8) {
            if measurementTypes.count >= 2 {
                measurementFilterChips
            } else {
                Spacer(minLength: 0)
            }
            Button {
                showingChart = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chart.xyaxis.line")
                    Text("图表")
                }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Theme.accentTint))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("查看图表")
        }
        .padding(.leading, 16)
    }

    private var measurementFilterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ChipButton(title: String(localized: "全部 \(measurements.count)"), isSelected: effectiveMeasurementFilter == nil) {
                    withAnimation { measurementFilter = nil }
                }
                ForEach(measurementTypes, id: \.name) { type in
                    ChipButton(title: "\(LogTypePreset.displayName(type.name)) \(type.count)",
                               isSelected: effectiveMeasurementFilter == type.name) {
                        withAnimation { measurementFilter = type.name }
                    }
                }
            }
            .padding(.vertical, 1)
        }
    }

    /// Hidden NavigationLink behind the card, so List doesn't draw a chevron.
    private func linkedCard<Content: View>(_ log: Log, @ViewBuilder content: () -> Content) -> some View {
        ZStack {
            NavigationLink(value: log) { EmptyView() }
                .opacity(0)
            content()
        }
    }

    private func deleteLog(_ log: Log) {
        modelContext.deleteLog(log)
        try? modelContext.save()
    }
}

// MARK: - Timeline rail

/// Left-hand vertical line + dot. Each row draws its own segment at full
/// height, so consecutive rows join into one continuous rail.
private struct TimelineRail<Content: View>: View {
    enum Marker {
        case accent, muted, upcoming, none
    }

    let marker: Marker
    let isLast: Bool
    @ViewBuilder let content: Content

    private let railWidth: CGFloat = 14
    private let dotTop: CGFloat = 22

    var body: some View {
        content
            .padding(.bottom, Theme.Spacing.cardGap)
            .padding(.leading, railWidth + 10)
            // Drawn as a background so the rail takes the row's real height.
            .background(alignment: .topLeading) {
                ZStack(alignment: .top) {
                    Rectangle()
                        .fill(Theme.border)
                        .frame(width: 1.5, height: isLast ? dotTop : nil)
                        .frame(maxHeight: .infinity, alignment: .top)
                    dot
                        .padding(.top, dotTop - 6)
                }
                .frame(width: railWidth)
            }
    }

    @ViewBuilder
    private var dot: some View {
        switch marker {
        case .accent:
            Circle().fill(Theme.accent).frame(width: 12, height: 12)
                .overlay(Circle().stroke(Theme.background, lineWidth: 2))
        case .muted:
            Circle().fill(Theme.inkSecondary.opacity(0.6)).frame(width: 10, height: 10)
                .overlay(Circle().stroke(Theme.background, lineWidth: 2))
                .frame(width: 12, height: 12)
        case .upcoming:
            Circle()
                .strokeBorder(Theme.accent, style: StrokeStyle(lineWidth: 1.5, dash: [3, 2]))
                .background(Circle().fill(Theme.background))
                .frame(width: 12, height: 12)
        case .none:
            EmptyView()
        }
    }
}

// MARK: - Cards

private struct LogCard: View {
    let log: Log

    private var note: String? {
        guard let note = log.note?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty else { return nil }
        return note
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: log.kind.iconName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.accent)
                BilingualTitle(primary: title, secondary: subtitle)
                Spacer(minLength: 8)
                Text(timestamp)
                    .font(.caption)
                    .foregroundStyle(Theme.inkSecondary)
            }

            switch log.kind {
            case .encounter:
                encounterBody
            case .quick, .measurement:
                quickBody
            }

            if !log.artifacts.isEmpty {
                Label("附件 \(log.artifacts.count) 份", systemImage: "paperclip")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Theme.accent)
            }
        }
        .cardSurface()
    }

    private var title: String {
        switch log.kind {
        case .encounter:
            return log.type.isEmpty ? log.kind.displayName : "\(log.kind.displayName) · \(log.typeDisplayName)"
        case .quick, .measurement:
            return log.kind.displayName
        }
    }

    private var subtitle: String? {
        switch log.kind {
        case .encounter: return LogTypePreset.encounterGloss(log.type)
        case .quick, .measurement: return log.kind.englishGloss.map { "· \($0)" }
        }
    }

    private var timestamp: String {
        // Encounters only capture a date; quick notes carry a meaningful time.
        log.kind == .encounter ? log.occurredAt.shortDay : log.occurredAt.shortDayTime
    }

    @ViewBuilder
    private var encounterBody: some View {
        let place = [log.location, log.doctor]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if !place.isEmpty {
            Text(place.joined(separator: " · "))
                .font(.subheadline)
                .foregroundStyle(Theme.inkPrimary)
        }
        if let note {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "note.text")
                    .font(.footnote)
                    .foregroundStyle(Theme.accent)
                Text("备注：\(note)")
                    .font(.footnote)
                    .foregroundStyle(Theme.inkPrimary)
                    .lineLimit(3)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.inset).fill(Theme.insetFill))
        }
    }

    @ViewBuilder
    private var quickBody: some View {
        if let note {
            Text(note)
                .font(.subheadline)
                .foregroundStyle(Theme.inkPrimary)
                .lineLimit(4)
                .lineSpacing(3)
        }
        if !log.type.isEmpty {
            TagPill(text: "# \(log.typeDisplayName)")
        }
    }
}

/// Future-dated encounter: dashed apricot outline on a tinted card.
private struct UpcomingCard: View {
    let log: Log

    private var detail: String? {
        let parts = [log.location, log.doctor, log.note]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: "calendar.badge.clock")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.accent)
                BilingualTitle(primary: String(localized: "下次 · \(log.typeDisplayName)"), secondary: AppLanguage.gloss(String(localized: "(Upcoming)")))
                Spacer(minLength: 8)
                Text(log.occurredAt.shortDay)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.accent)
            }
            HStack(spacing: 8) {
                TagPill(text: log.daysUntilLabel, tinted: true)
                if let detail {
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(Theme.inkPrimary)
                        .lineLimit(2)
                }
            }
        }
        .padding(Theme.Spacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.card).fill(Theme.accentTint.opacity(0.6)))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .strokeBorder(Theme.accent.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
        )
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
            IconBadge(systemName: LogKind.measurement.iconName)
            VStack(alignment: .leading, spacing: 3) {
                BilingualTitle(primary: LogKind.measurement.displayName, secondary: LogKind.measurement.englishGloss.map { "· \($0)" })
                if let recent = mostRecent {
                    Text("\(logs.count) 次记录 · 最近 \(recent.typeDisplayName) \(recent.formattedValue)")
                        .font(.footnote)
                        .foregroundStyle(Theme.inkSecondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            HStack(spacing: 2) {
                Text(expanded ? String(localized: "收起") : String(localized: "展开"))
                Image(systemName: expanded ? "chevron.down" : "chevron.right")
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Theme.accent)
        }
        .cardSurface()
        .contentShape(Rectangle())
    }
}

private struct MeasurementRow: View {
    let log: Log

    var body: some View {
        HStack {
            Text(LogTypePreset.displayName(log.type))
                .font(.subheadline)
                .foregroundStyle(Theme.inkPrimary)
            Spacer()
            Text(log.formattedValue)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(Theme.inkPrimary)
            Text(log.occurredAt.shortDayTime)
                .font(.caption)
                .foregroundStyle(Theme.inkSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.inset)
                .fill(Theme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.inset)
                .stroke(Theme.border, lineWidth: 1)
        )
        .padding(.leading, 16)
    }
}
