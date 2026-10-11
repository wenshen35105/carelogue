import SwiftUI
import Charts

/// 测量趋势图（sheet from the expanded measurement group）. Reads straight
/// from `journey.logs`, so new or edited measurements redraw automatically.
struct MeasurementChartView: View {
    @Environment(\.dismiss) private var dismiss

    let journey: Journey
    @State private var selectedType: String

    init(journey: Journey, initialType: String?) {
        self.journey = journey
        _selectedType = State(initialValue: initialType ?? Self.types(in: journey).first ?? "")
    }

    private static func types(in journey: Journey) -> [String] {
        let counts = Dictionary(grouping: journey.allLogs.filter { $0.kind == .measurement }, by: \.type)
            .mapValues(\.count)
        return counts.keys.sorted { counts[$0]! != counts[$1]! ? counts[$0]! > counts[$1]! : $0 < $1 }
    }

    private var types: [String] { Self.types(in: journey) }

    /// Chronological points of the selected type that carry a value.
    private var points: [Log] {
        journey.allLogs
            .filter { $0.kind == .measurement && $0.type == selectedType && $0.value != nil }
            .sorted { $0.occurredAt < $1.occurredAt }
    }

    private var typeName: String {
        selectedType.isEmpty ? LogKind.measurement.displayName : LogTypePreset.displayName(selectedType)
    }

    private var unit: String {
        points.last?.unit ?? ""
    }

    /// M8 T57: blood pressure draws two lines, systolic and diastolic.
    private var isBloodPressure: Bool { selectedType == LogTypePreset.bloodPressure }

    /// One plotted reading: which line it belongs to, and where.
    private struct Point: Identifiable {
        let id: String
        let series: String
        let date: Date
        let value: Double
    }

    private static var systolicName: String { String(localized: "收缩压") }
    private static var diastolicName: String { String(localized: "舒张压") }

    /// Every reading to plot. Old single-value blood pressures only add to
    /// the systolic line.
    private func plotted(_ points: [Log]) -> [Point] {
        points.flatMap { log -> [Point] in
            guard let value = log.value else { return [] }
            guard isBloodPressure else {
                return [Point(id: log.id.uuidString, series: typeName, date: log.occurredAt, value: value)]
            }
            var result = [Point(id: "\(log.id.uuidString)-s", series: Self.systolicName, date: log.occurredAt, value: value)]
            if let diastolic = log.diastolic {
                result.append(Point(id: "\(log.id.uuidString)-d", series: Self.diastolicName, date: log.occurredAt, value: diastolic))
            }
            return result
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if types.count >= 2 {
                        typePicker
                    }
                    let points = self.points
                    if points.isEmpty {
                        emptyState
                    } else {
                        summaryCard(points)
                        chartCard(points)
                    }
                }
                .padding(Theme.Spacing.margin)
            }
            .background(Theme.background)
            .navigationTitle("趋势 · Trends")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    // MARK: - Sections

    private var typePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(types, id: \.self) { type in
                    ChipButton(title: LogTypePreset.displayName(type), isSelected: type == selectedType) {
                        withAnimation { selectedType = type }
                    }
                }
            }
            .padding(.vertical, 1)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 30))
                .foregroundStyle(Theme.inkSecondary)
            Text("还没有「\(typeName)」的数值记录")
                .font(.subheadline)
                .foregroundStyle(Theme.inkSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .cardSurface()
    }

    /// Latest value in large tabular digits + change since the first point.
    private func summaryCard(_ points: [Log]) -> some View {
        let latest = points.last!
        let values = points.compactMap(\.value)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                IconBadge(systemName: LogKind.measurement.iconName)
                BilingualTitle(primary: typeName, secondary: String(localized: "· 最新 Latest"))
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(latest.formattedNumber ?? Self.format(latest.value ?? 0))
                    .font(.system(size: 34, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.inkPrimary)
                Text(unit)
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSecondary)
                Spacer(minLength: 8)
                if !isBloodPressure, values.count >= 2, let first = values.first, let last = values.last {
                    let delta = last - first
                    TagPill(text: String(localized: "较首次 \(delta >= 0 ? "+" : "−")\(Self.format(abs(delta)))\(unit)"), tinted: true)
                }
            }
            if isBloodPressure {
                let diastolics = points.compactMap(\.diastolic)
                Text("\(points.count) 次记录 · 收缩压 \(Self.range(values)) · 舒张压 \(diastolics.isEmpty ? "--" : Self.range(diastolics)) · 最近 \(latest.occurredAt.shortDay)")
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSecondary)
            } else {
                Text("\(points.count) 次记录 · 最低 \(Self.format(values.min() ?? 0)) · 最高 \(Self.format(values.max() ?? 0)) · 最近 \(latest.occurredAt.shortDay)")
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSecondary)
            }
        }
        .cardSurface()
    }

    private func chartCard(_ points: [Log]) -> some View {
        let plotted = plotted(points)
        let values = plotted.map(\.value)
        let yDomain = Self.paddedDomain(min: values.min() ?? 0, max: values.max() ?? 0)
        let xDomain = Self.dateDomain(points.map(\.occurredAt))
        let series = isBloodPressure ? [Self.systolicName, Self.diastolicName] : [typeName]

        return VStack(alignment: .leading, spacing: 12) {
            Chart(plotted) { point in
                // The area fill only under a single line; two would muddy it.
                if !isBloodPressure {
                    AreaMark(
                        x: .value("日期", point.date),
                        yStart: .value("基线", yDomain.lowerBound),
                        yEnd: .value(typeName, point.value)
                    )
                    .foregroundStyle(LinearGradient(
                        colors: [Theme.accent.opacity(0.18), Theme.accent.opacity(0)],
                        startPoint: .top, endPoint: .bottom
                    ))
                    .interpolationMethod(.monotone)
                }

                LineMark(
                    x: .value("日期", point.date),
                    y: .value(typeName, point.value),
                    series: .value("系列", point.series)
                )
                .foregroundStyle(by: .value("系列", point.series))
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .interpolationMethod(.monotone)

                PointMark(
                    x: .value("日期", point.date),
                    y: .value(typeName, point.value)
                )
                .foregroundStyle(by: .value("系列", point.series))
                .symbolSize(points.count > 30 ? 12 : 30)
            }
            .chartForegroundStyleScale(domain: series, range: [Theme.accent, Theme.inkSecondary].prefix(series.count).map { $0 })
            .chartLegend(isBloodPressure ? .visible : .hidden)
            .chartLegend(position: .top, alignment: .leading)
            .chartXScale(domain: xDomain)
            .chartYScale(domain: yDomain)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                    AxisGridLine().foregroundStyle(Theme.border)
                    AxisValueLabel(format: .dateTime.month(.defaultDigits).day())
                        .foregroundStyle(Theme.inkSecondary)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { _ in
                    AxisGridLine().foregroundStyle(Theme.border)
                    AxisValueLabel().foregroundStyle(Theme.inkSecondary)
                }
            }
            .frame(height: 240)
            .accessibilityLabel("\(typeName)趋势图，共 \(points.count) 个点")

            if points.count == 1 {
                Text("只有 1 条记录，再记一次就能看到趋势")
                    .font(.caption)
                    .foregroundStyle(Theme.inkSecondary)
            }
        }
        .cardSurface()
    }

    // MARK: - Helpers

    private static func format(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
    }

    /// "110–128".
    private static func range(_ values: [Double]) -> String {
        "\(format(values.min() ?? 0))–\(format(values.max() ?? 0))"
    }

    /// Adds headroom so a flat or single-value series doesn't hug the edges.
    private static func paddedDomain(min: Double, max: Double) -> ClosedRange<Double> {
        let span = max - min
        let pad = span > 0 ? span * 0.2 : Swift.max(abs(max) * 0.05, 1)
        return (min - pad)...(max + pad)
    }

    /// A single point gets a ±3-day window so the axis has a real range.
    private static func dateDomain(_ dates: [Date]) -> ClosedRange<Date> {
        guard let first = dates.min(), let last = dates.max() else { return Date.now...Date.now }
        if first == last || last.timeIntervalSince(first) < 86_400 {
            let day: TimeInterval = 86_400
            return first.addingTimeInterval(-3 * day)...last.addingTimeInterval(3 * day)
        }
        let pad = last.timeIntervalSince(first) * 0.04
        return first.addingTimeInterval(-pad)...last.addingTimeInterval(pad)
    }
}
