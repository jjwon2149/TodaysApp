import SwiftUI

enum AppTheme {
    enum Colors {
        static let background = Color(uiColor: .systemGroupedBackground)
        static let card = Color(uiColor: .secondarySystemGroupedBackground)
        static let cardStroke = Color(uiColor: .separator).opacity(0.28)
        static let accent = Color(red: 0.96, green: 0.46, blue: 0.30)
        static let accentDeep = Color(red: 0.73, green: 0.24, blue: 0.18)
        static let secondaryAccent = Color(uiColor: .systemOrange).opacity(0.12)
        static let highlight = Color(red: 0.98, green: 0.72, blue: 0.36)
        static let success = Color(red: 0.28, green: 0.66, blue: 0.46)
        static let textPrimary = Color(uiColor: .label)
        static let textSecondary = Color.secondary
        static let muted = Color(uiColor: .tertiarySystemFill)

        static let brandGradient = LinearGradient(
            colors: [accent, accentDeep],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
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
