import SwiftUI

enum AppTheme {
    enum Colors {
        static let background = Color(red: 0.035, green: 0.045, blue: 0.075)
        static let surface = Color(red: 0.09, green: 0.105, blue: 0.15)
        static let elevatedSurface = Color(red: 0.14, green: 0.16, blue: 0.22)
        static let accent = Color(red: 0.45, green: 0.35, blue: 1)
        static let secondaryAccent = Color(red: 0.15, green: 0.82, blue: 0.74)
        static let primaryText = Color.white
        static let secondaryText = Color.white.opacity(0.65)
    }

    enum Spacing {
        static let small: CGFloat = 8
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
        static let extraLarge: CGFloat = 32
    }

    enum Radius {
        static let small: CGFloat = 10
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
    }
}
