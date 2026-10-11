import SwiftUI
import UIKit
import WidgetKit

// M8 T58 · the widget's faces. In Shared/ so the app can also draw them
// (Debug builds render a gallery for screenshots and UI tests).

/// The widget's own copy of the palette (Theme lives in the app target).
enum WidgetPalette {
    private static func dynamic(_ light: String, _ dark: String) -> Color {
        func color(_ hex: String) -> UIColor {
            var value: UInt64 = 0
            Scanner(string: hex).scanHexInt64(&value)
            return UIColor(red: CGFloat((value >> 16) & 0xFF) / 255, green: CGFloat((value >> 8) & 0xFF) / 255,
                           blue: CGFloat(value & 0xFF) / 255, alpha: 1)
        }
        return Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? color(dark) : color(light) })
    }

    static let accent = dynamic("D9784F", "E08A63")
    static let accentTint = dynamic("FAF0EA", "3A2A21")
    static let background = dynamic("FFFFFF", "221E1A")
    static let inkPrimary = dynamic("1C1B1A", "F5F1EC")
    static let inkSecondary = dynamic("8A8680", "A39C93")
}

/// Strings live in Widget.xcstrings, which both targets compile. With a
/// language, they come from that localization rather than the device's.
func widgetText(_ key: String.LocalizationValue, language: String? = nil) -> String {
    if let language, let path = Bundle.main.path(forResource: language, ofType: "lproj"),
       let bundle = Bundle(path: path) {
        return String(localized: key, table: "Widget", bundle: bundle)
    }
    return String(localized: key, table: "Widget")
}

struct CarelogueWidgetView: View {
    let snapshot: WidgetSnapshot?
    let date: Date
    let isMedium: Bool

    private var calendar: Calendar { .current }
    private var language: String? { snapshot?.language }
    private var locale: Locale { language.map(Locale.init(identifier:)) ?? .current }

    private func text(_ key: String.LocalizationValue) -> String {
        widgetText(key, language: language)
    }

    var body: some View {
        HStack(spacing: 12) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            if isMedium, snapshot?.quickNoteJourneyID != nil {
                quickNoteButton
            }
        }
        .widgetURL(primaryLink.url)
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        if let visit = snapshot?.nextVisit {
            itemView(visit, header: text("下次就诊"), icon: "calendar.badge.clock",
                     headline: countdown(to: visit.date), time: visit.date.formatted(.dateTime.month().day().hour().minute().locale(locale)))
        } else if let latest = snapshot?.latest {
            itemView(latest, header: text("最近记录"), icon: "clock.arrow.circlepath",
                     headline: latest.title, time: latest.date.formatted(.dateTime.month().day().locale(locale)))
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Label(text("Carelogue"), systemImage: "leaf")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(WidgetPalette.accent)
                Spacer(minLength: 0)
                Text(text("记录今天"))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(WidgetPalette.inkPrimary)
                Text(text("一条随手记就是开始"))
                    .font(.caption)
                    .foregroundStyle(WidgetPalette.inkSecondary)
            }
        }
    }

    private func itemView(_ item: WidgetSnapshot.Item, header: String, icon: String,
                          headline: String, time: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Label(header, systemImage: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(WidgetPalette.accent)
                .lineLimit(1)
            Spacer(minLength: 2)
            Text(headline)
                .font(.title2.weight(.bold))
                .foregroundStyle(WidgetPalette.inkPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if snapshot?.nextVisit != nil {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(WidgetPalette.inkPrimary)
                    .lineLimit(1)
            }
            Text(time)
                .font(.caption)
                .foregroundStyle(WidgetPalette.inkSecondary)
                .lineLimit(1)
            if isMedium, let detail = item.detail, !detail.isEmpty {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(WidgetPalette.inkSecondary)
                    .lineLimit(1)
            }
            Text(item.journeyName)
                .font(.caption2)
                .foregroundStyle(WidgetPalette.inkSecondary)
                .lineLimit(1)
        }
    }

    private var quickNoteButton: some View {
        Link(destination: DeepLink.quickNote(snapshot?.quickNoteJourneyID).url) {
            VStack(spacing: 6) {
                Image(systemName: "square.and.pencil")
                    .font(.title3.weight(.semibold))
                Text(text("记一笔"))
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(WidgetPalette.accent)
            .frame(width: 76)
            .frame(maxHeight: .infinity)
            .background(RoundedRectangle(cornerRadius: 14).fill(WidgetPalette.accentTint))
        }
    }

    /// 今天 / 明天 / 3 天后.
    private func countdown(to day: Date) -> String {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date),
                                           to: calendar.startOfDay(for: day)).day ?? 0
        switch days {
        case ...0: return text("今天")
        case 1: return text("明天")
        default: return text("\(days) 天后")
        }
    }

    /// Where a tap anywhere else goes.
    private var primaryLink: DeepLink {
        if let visit = snapshot?.nextVisit { return .log(visit.logID) }
        if let latest = snapshot?.latest { return .log(latest.logID) }
        return .quickNote(snapshot?.quickNoteJourneyID)
    }
}
