import Foundation

/// One key/value chip under a journey's title (M8 T55): 血型 · O+.
struct JourneySummaryItem: Codable, Hashable {
    var key: String
    var value: String
}

extension Journey {
    /// Items with both a key and a value, in the user's order.
    var summaryItems: [JourneySummaryItem] {
        get {
            guard let data = summaryItemsJSON?.data(using: .utf8),
                  let items = try? JSONDecoder().decode([JourneySummaryItem].self, from: data) else { return [] }
            return items
        }
        set {
            let kept = newValue
                .map { JourneySummaryItem(key: $0.key.trimmingCharacters(in: .whitespacesAndNewlines),
                                          value: $0.value.trimmingCharacters(in: .whitespacesAndNewlines)) }
                .filter { !$0.key.isEmpty && !$0.value.isEmpty }
            summaryItemsJSON = kept.isEmpty ? nil : (try? JSONEncoder().encode(kept)).flatMap { String(data: $0, encoding: .utf8) }
        }
    }

    /// The progress toward `targetDate` (T56), nil when there is none.
    func progress(now: Date = .now) -> JourneyProgress? {
        guard let targetDate else { return nil }
        return JourneyProgress(start: progressStartDate ?? createdAt, target: targetDate, now: now)
    }
}

/// Start → target, measured in whole calendar days.
struct JourneyProgress: Equatable {
    let start: Date
    let target: Date
    let now: Date

    private var calendar: Calendar { .current }

    private func days(_ from: Date, _ to: Date) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: from), to: calendar.startOfDay(for: to)).day ?? 0
    }

    /// Days from today to the target (negative once it has passed).
    var daysLeft: Int { days(now, target) }

    var totalDays: Int { max(days(start, target), 1) }

    var elapsedDays: Int { days(start, now) }

    var fraction: Double { min(max(Double(elapsedDays) / Double(totalDays), 0), 1) }

    var percent: Int { Int((fraction * 100).rounded()) }

    /// Completed weeks since the start ("第 26 周" at 182 days, the way
    /// pregnancy weeks are counted). Nil in the first week or before the
    /// start, where "第 0 周" would only confuse.
    var week: Int? {
        let weeks = elapsedDays / 7
        return weeks >= 1 ? weeks : nil
    }
}

extension JourneyTemplate {
    /// Names offered for the target day; the first is pre-filled.
    var targetLabelSuggestions: [String] {
        switch self {
        case .pregnancy: return [String(localized: "预产期")]
        case .toothExtraction: return [String(localized: "拔牙日"), String(localized: "复查日")]
        case .custom: return [String(localized: "手术日"), String(localized: "复查日"), String(localized: "目标日")]
        }
    }

    /// Summary keys offered as one-tap empty slots.
    var summaryKeySuggestions: [String] {
        switch self {
        case .pregnancy: return [String(localized: "血型"), String(localized: "产科医生 OB")]
        case .toothExtraction: return [String(localized: "牙医")]
        case .custom: return [String(localized: "主治医生")]
        }
    }

    /// Where progress should start for a target, when the template knows
    /// better than "the day the journey was created": a pregnancy is
    /// counted from 40 weeks before the due date.
    func suggestedStart(forTarget target: Date) -> Date? {
        switch self {
        case .pregnancy: return Calendar.current.date(byAdding: .day, value: -280, to: target)
        case .toothExtraction, .custom: return nil
        }
    }
}
