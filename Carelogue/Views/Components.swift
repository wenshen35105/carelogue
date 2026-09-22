import SwiftUI

// Shared presentation helpers used across Journey list, timeline and detail.
// Everything here is derived from existing model fields — no schema changes.

// MARK: - Display names

extension JourneyTemplate {
    /// Small-caps English label shown next to a Journey's name (Stitch: "PREGNANCY").
    var englishLabel: String? {
        switch self {
        case .pregnancy: return String(localized: "PREGNANCY")
        case .toothExtraction: return String(localized: "TOOTH EXTRACTION")
        case .custom: return nil
        }
    }
}

extension JourneyStatus {
    /// "进行中 Active" / "Active".
    var pillLabel: String {
        switch self {
        case .active: return String(localized: "进行中 Active")
        case .done: return String(localized: "已完成 Done")
        }
    }
}

extension LogKind {
    var displayName: String {
        switch self {
        case .encounter: return String(localized: "就诊")
        case .quick: return String(localized: "随手记")
        case .measurement: return String(localized: "测量")
        }
    }

    /// English sub-label next to the Chinese kind name (Chinese UI only).
    var englishGloss: String? {
        switch self {
        case .encounter: return AppLanguage.gloss(String(localized: "Visit"))
        case .quick: return AppLanguage.gloss(String(localized: "Quick Note"))
        case .measurement: return AppLanguage.gloss(String(localized: "Vitals"))
        }
    }

    /// "就诊 Visit" / "Visit" pill text.
    var pillLabel: String {
        [displayName, englishGloss].compactMap { $0 }.joined(separator: " ")
    }

    var iconName: String {
        switch self {
        case .encounter: return "stethoscope"
        case .quick: return "square.and.pencil"
        case .measurement: return "waveform.path.ecg"
        }
    }
}

extension LogKind: Identifiable {
    public var id: String { rawValue }
}

/// Preset Log sub-types. The stored value stays the Chinese preset name
/// (data written before localization keeps working); only its display is
/// localized. Custom (user-typed) types are shown verbatim.
enum LogTypePreset {
    static let encounter = ["面诊", "体检", "验血", "影像", "其他"]
    static let quick = ["症状", "情绪", "备注"]
    /// Measurement presets with their default unit; 自定义 = user-named type.
    static let measurement: [(name: String, unit: String)] = [
        ("体重", "kg"), ("血压", "mmHg"), ("体温", "°C"), ("自定义", "")
    ]
    static let custom = "自定义"

    static func displayName(_ raw: String) -> String {
        switch raw {
        case "面诊": return String(localized: "面诊")
        case "体检": return String(localized: "体检")
        case "验血": return String(localized: "验血")
        case "影像": return String(localized: "影像")
        case "其他": return String(localized: "其他")
        case "症状": return String(localized: "症状")
        case "情绪": return String(localized: "情绪")
        case "备注": return String(localized: "备注")
        case "体重": return String(localized: "体重")
        case "血压": return String(localized: "血压")
        case "体温": return String(localized: "体温")
        case "自定义": return String(localized: "自定义")
        case "": return String(localized: "未命名")
        default: return raw
        }
    }

    /// English sub-label for preset encounter types, e.g. 面诊 -> (In-Person).
    /// Chinese UI only; English UI already shows the English name.
    static func encounterGloss(_ raw: String) -> String? {
        let english: String?
        switch raw {
        case "面诊": english = String(localized: "(In-Person)")
        case "体检": english = String(localized: "(Checkup)")
        case "验血": english = String(localized: "(Blood Test)")
        case "影像": english = String(localized: "(Imaging)")
        default: english = nil
        }
        return AppLanguage.gloss(english)
    }
}

extension Log {
    /// Localized sub-type for display; falls back to the kind name when empty.
    var typeDisplayName: String {
        type.isEmpty ? kind.displayName : LogTypePreset.displayName(type)
    }

    var formattedValue: String {
        guard let value else { return "--" }
        let numberString = value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
        return "\(numberString)\(unit ?? "")"
    }

    /// An encounter dated on a future day is treated as an upcoming
    /// appointment. Day granularity because the encounter editor only
    /// captures a date, not a time.
    var isUpcoming: Bool {
        guard kind == .encounter else { return false }
        let calendar = Calendar.current
        return calendar.startOfDay(for: occurredAt) > calendar.startOfDay(for: .now)
    }

    /// "明天" / "距今 11 天" pill for an upcoming appointment.
    var daysUntilLabel: String {
        daysFromToday == 1 ? String(localized: "明天") : String(localized: "距今 \(daysFromToday) 天")
    }

    /// Whole days from today until this log's day (0 = today).
    var daysFromToday: Int {
        let calendar = Calendar.current
        return calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: .now),
            to: calendar.startOfDay(for: occurredAt)
        ).day ?? 0
    }
}

extension Journey {
    /// The soonest upcoming encounter, if any.
    var nextAppointment: Log? {
        logs.filter(\.isUpcoming).min { $0.occurredAt < $1.occurredAt }
    }

    /// Most recent log that has already happened.
    var latestPastLog: Log? {
        logs.filter { !$0.isUpcoming }.max { $0.occurredAt < $1.occurredAt }
    }

    var artifactCount: Int {
        logs.reduce(0) { $0 + $1.artifacts.count }
    }
}

// MARK: - Date formatting

extension Date {
    /// "10月2日" / "Oct 2"
    var shortDay: String {
        formatted(.dateTime.month(.abbreviated).day().locale(AppLanguage.locale))
    }

    /// "10月2日 22:15" / "Oct 2, 10:15 PM"
    var shortDayTime: String {
        formatted(.dateTime.month(.abbreviated).day().hour().minute().locale(AppLanguage.locale))
    }

    /// "2026年9月" / "Sep 2026"
    var yearMonth: String {
        formatted(.dateTime.year().month(.abbreviated).locale(AppLanguage.locale))
    }

    /// "2026/9/2" / "9/2/2026"
    var numericDate: String {
        formatted(.dateTime.year().month(.defaultDigits).day().locale(AppLanguage.locale))
    }
}

// MARK: - Small components

/// "进行中 Active" / "已完成 Done" capsule.
struct StatusPill: View {
    let status: JourneyStatus

    var body: some View {
        HStack(spacing: 5) {
            if status == .active {
                Circle().fill(Theme.accent).frame(width: 6, height: 6)
            } else {
                Image(systemName: "checkmark.circle")
                    .font(.caption2)
            }
            Text(status.pillLabel)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(status == .active ? Theme.accent : Theme.inkSecondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(status == .active ? Theme.accentTint : Theme.border.opacity(0.6)))
    }
}

/// Apricot SF Symbol on a tinted circular badge (DESIGN.md metric badge).
struct IconBadge: View {
    let systemName: String
    var size: CGFloat = 32

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.45, weight: .medium))
            .foregroundStyle(Theme.accent)
            .frame(width: size, height: size)
            .background(Circle().fill(Theme.accentTint))
    }
}

/// Small pill tag, e.g. "# 症状" or "距今 11 天".
struct TagPill: View {
    let text: String
    var tinted = false

    var body: some View {
        Text(text)
            .font(.caption.weight(.medium))
            .foregroundStyle(tinted ? Theme.accent : Theme.inkSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(tinted ? Theme.accentTint : Theme.insetFill))
    }
}

/// "中文 · English" title pair used on card headers. `secondary` is the
/// English gloss — pass it through `AppLanguage.gloss` so English UI shows
/// the primary text only.
struct BilingualTitle: View {
    let primary: String
    let secondary: String?
    var font: Font = .headline

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(primary)
                .font(font)
                .foregroundStyle(Theme.inkPrimary)
            if let secondary {
                Text(secondary)
                    .font(.caption)
                    .foregroundStyle(Theme.inkSecondary)
            }
        }
        .lineLimit(1)
    }
}

/// Selectable pill chip (type pickers in the editor, filters on the timeline).
struct ChipButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(isSelected ? Theme.accent : Theme.inkSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(isSelected ? Theme.accent.opacity(0.12) : Theme.card)
                )
                .overlay(
                    Capsule().stroke(isSelected ? Theme.accent : Theme.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
