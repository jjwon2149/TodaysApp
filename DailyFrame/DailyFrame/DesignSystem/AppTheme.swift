import SwiftUI

enum AppTheme {
    enum Colors {
        static let background = Color(uiColor: .systemGroupedBackground)
        static let card = Color(uiColor: .secondarySystemGroupedBackground)
        static let cardStroke = Color(uiColor: .separator).opacity(0.28)
        static let accent = Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 1.0, green: 0.62, blue: 0.48, alpha: 1)
                : UIColor(red: 0.68, green: 0.20, blue: 0.13, alpha: 1)
        })
        static let accentFill = Color(red: 0.62, green: 0.17, blue: 0.10)
        static let accentDeep = Color(red: 0.42, green: 0.11, blue: 0.08)
        static let onAccent = Color.white
        static let secondaryAccent = Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.92, green: 0.34, blue: 0.20, alpha: 0.24)
                : UIColor(red: 0.68, green: 0.20, blue: 0.13, alpha: 0.12)
        })
        static let highlight = Color(red: 0.98, green: 0.72, blue: 0.36)
        static let success = Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.48, green: 0.86, blue: 0.62, alpha: 1)
                : UIColor(red: 0.08, green: 0.43, blue: 0.24, alpha: 1)
        })
        static let textPrimary = Color(uiColor: .label)
        static let textSecondary = Color.secondary
        static let muted = Color(uiColor: .tertiarySystemFill)

        static let brandGradient = LinearGradient(
            colors: [accentFill, accentDeep],
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
