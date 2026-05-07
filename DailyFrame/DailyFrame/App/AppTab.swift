import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case home
    case calendar
    case profile

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home:
            return L10n.string("tab.home")
        case .calendar:
            return L10n.string("tab.calendar")
        case .profile:
            return L10n.string("tab.profile")
        }
    }

    var systemImage: String {
        switch self {
        case .home:
            return "house.fill"
        case .calendar:
            return "calendar"
        case .profile:
            return "person.crop.circle"
        }
    }
}
