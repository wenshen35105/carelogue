import SwiftUI
import UIKit

extension UIColor {
    /// Hex initializer for the design system's palette (see CLAUDE.md).
    convenience init(hex: String, alpha: CGFloat = 1) {
        var value: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&value)
        self.init(
            red: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: alpha
        )
    }
}

extension Color {
    /// Convenience initializer for the design system's hex palette (see CLAUDE.md).
    init(hex: String) {
        self.init(uiColor: UIColor(hex: hex))
    }

    /// Follows the system appearance: light value by default, dark value
    /// under Dark Mode (Stitch "Nocturne" palette).
    static func dynamic(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }

    static func dynamic(light: String, dark: String) -> Color {
        dynamic(light: UIColor(hex: light), dark: UIColor(hex: dark))
    }
}

/// Single source of truth for colours. Every token is dynamic; views never
/// branch on colorScheme themselves.
enum Theme {
    /// UI copy is Simplified-Chinese-first (CLAUDE.md); force this locale for
    /// date/time formatting instead of following the device's system locale.
    static let locale = Locale(identifier: "zh_Hans")

    static let accent = Color.dynamic(light: "D9784F", dark: "E08A63")
    /// Low-intensity apricot fill for chips, icon badges and soft highlights (DESIGN.md).
    /// Dark: accent at 15% so it blends with whatever surface sits beneath.
    static let accentTint = Color.dynamic(light: UIColor(hex: "FAF0EA"), dark: UIColor(hex: "E08A63", alpha: 0.15))
    /// Foreground on a solid accent fill (FAB "+").
    static let onAccent = Color.dynamic(light: "FFFFFF", dark: "F5F1EC")
    static let background = Color.dynamic(light: "F7F5F2", dark: "17140F")
    static let card = Color.dynamic(light: "FFFFFF", dark: "221E1A")
    /// Inset blocks inside a card (e.g. an encounter's note box).
    static let insetFill = Color.dynamic(light: "F7F5F2", dark: "1C1814")
    /// Raised layer above a card (dark-mode tonal step; same as card in light).
    static let raised = Color.dynamic(light: "FFFFFF", dark: "2C2621")
    static let inkPrimary = Color.dynamic(light: "1C1B1A", dark: "F5F1EC")
    static let inkSecondary = Color.dynamic(light: "8A8680", dark: "A39C93")
    static let border = Color.dynamic(light: "EAE6DF", dark: "332E28")
    /// Card shadow: ultra-diffused warm shadow in light; dark mode drops
    /// shadows and relies on tonal layering + hairline borders instead.
    static let cardShadow = Color.dynamic(light: UIColor(hex: "1C1B1A", alpha: 0.04), dark: .clear)

    enum Radius {
        static let card: CGFloat = 18
        static let inset: CGFloat = 12
        static let button: CGFloat = 12
        static let pill: CGFloat = 999
    }

    enum Spacing {
        /// Horizontal screen margin (DESIGN.md: 20pt).
        static let margin: CGFloat = 20
        /// Vertical gap between stacked cards.
        static let cardGap: CGFloat = 12
        static let cardPadding: CGFloat = 16
    }
}

/// Level-1 surface from DESIGN.md: card fill, hairline border and an
/// ultra-diffused warm shadow (shadow drops out in dark mode).
private struct CardSurface: ViewModifier {
    var padding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.card)
                    .fill(Theme.card)
                    .shadow(color: Theme.cardShadow, radius: 10, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card)
                    .stroke(Theme.border, lineWidth: 1)
            )
    }
}

extension View {
    func cardSurface(padding: CGFloat = Theme.Spacing.cardPadding) -> some View {
        modifier(CardSurface(padding: padding))
    }

    /// Strips List chrome so a row can host a free-standing card on the canvas
    /// while keeping List-only behaviour such as swipe actions.
    func canvasListRow(top: CGFloat = 0, bottom: CGFloat = Theme.Spacing.cardGap) -> some View {
        listRowInsets(EdgeInsets(top: top, leading: Theme.Spacing.margin, bottom: bottom, trailing: Theme.Spacing.margin))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }
}
