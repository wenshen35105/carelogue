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
    static let background = Color(hex: "F7F5F2")
    static let card = Color(hex: "FFFFFF")
    static let inkPrimary = Color(hex: "1C1B1A")
    static let inkSecondary = Color(hex: "8A8680")
    static let border = Color(hex: "EAE6DF")

    enum Radius {
        static let card: CGFloat = 18
        static let button: CGFloat = 12
        static let pill: CGFloat = 999
    }
}
