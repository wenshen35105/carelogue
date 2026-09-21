import SwiftUI

// Shared presentation helpers used across Journey list, timeline and detail.
// Everything here is derived from existing model fields — no schema changes.

// MARK: - Display names

extension JourneyTemplate {
    /// Small-caps English label shown next to a Journey's name (Stitch: "PREGNANCY").
    var englishLabel: String? {
        switch self {
        case .pregnancy: return "PREGNANCY"
        case .toothExtraction: return "TOOTH EXTRACTION"
        case .custom: return nil
        }
    }
}

extension JourneyStatus {
    var englishName: String {
        switch self {
        case .active: return "Active"
        case .done: return "Done"
        }
    }
}

extension LogKind {
    var displayName: String {
        switch self {
        case .encounter: return "就诊"
        case .quick: return "随手记"
        case .measurement: return "测量"
        }
    }

    var englishName: String {
        switch self {
        case .encounter: return "Visit"
        case .quick: return "Quick Note"
        case .measurement: return "Vitals"
        }
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

extension Log {
    /// English gloss for the preset encounter sub-types, e.g. 面诊 -> In-Person.
    var typeEnglishName: String? {
        switch type {
        case "面诊": return "In-Person"
        case "体检": return "Checkup"
        case "验血": return "Blood Test"
        case "影像": return "Imaging"
        default: return nil
        }
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
    /// "10月2日"
    var shortDay: String {
        formatted(.dateTime.month(.defaultDigits).day().locale(Theme.locale))
    }

    /// "10月2日 22:15"
    var shortDayTime: String {
        formatted(.dateTime.month(.defaultDigits).day().hour().minute().locale(Theme.locale))
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
            Text("\(status.displayName) \(status.englishName)")
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

/// "中文 · English" title pair used on card headers.
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
    }
}
