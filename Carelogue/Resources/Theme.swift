import SwiftUI

extension Color {
    /// Convenience initializer for the design system's hex palette (see CLAUDE.md).
    init(hex: String) {
        var value: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&value)
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

enum Theme {
    /// UI copy is Simplified-Chinese-first (CLAUDE.md); force this locale for
    /// date/time formatting instead of following the device's system locale.
    static let locale = Locale(identifier: "zh_Hans")

    static let accent = Color(hex: "D9784F")
    /// Low-intensity apricot fill for chips, icon badges and soft highlights (DESIGN.md).
    static let accentTint = Color(hex: "FAF0EA")
    static let background = Color(hex: "F7F5F2")
    static let card = Color(hex: "FFFFFF")
    /// Inset blocks inside a card (e.g. an encounter's note box).
    static let insetFill = Color(hex: "F7F5F2")
    static let inkPrimary = Color(hex: "1C1B1A")
    static let inkSecondary = Color(hex: "8A8680")
    static let border = Color(hex: "EAE6DF")

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

/// Level-1 surface from DESIGN.md: white card, hairline linen border and an
/// ultra-diffused warm shadow.
private struct CardSurface: ViewModifier {
    var padding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.card)
                    .fill(Theme.card)
                    .shadow(color: Theme.inkPrimary.opacity(0.04), radius: 10, y: 4)
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
