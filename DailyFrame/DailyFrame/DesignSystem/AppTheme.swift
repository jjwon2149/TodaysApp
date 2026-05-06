import SwiftUI

enum AppTheme {
    enum Colors {
        static let background = Color(uiColor: .systemGroupedBackground)
        static let card = Color.white
        static let accent = Color(red: 0.96, green: 0.46, blue: 0.30)
        static let secondaryAccent = Color(red: 1.00, green: 0.95, blue: 0.87)
        static let success = Color(red: 0.28, green: 0.66, blue: 0.46)
        static let textPrimary = Color(red: 0.11, green: 0.13, blue: 0.18)
        static let textSecondary = Color.secondary
        static let muted = Color(red: 0.92, green: 0.93, blue: 0.95)
    }

    enum Spacing {
        static let xSmall: CGFloat = 8
        static let small: CGFloat = 12
        static let medium: CGFloat = 16
        static let large: CGFloat = 20
        static let xLarge: CGFloat = 28
    }

    enum Radius {
        static let medium: CGFloat = 18
        static let large: CGFloat = 28
    }
}
