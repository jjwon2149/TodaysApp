import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case home
    case calendar
    case profile

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home:
            return "오늘"
        case .calendar:
            return "캘린더"
        case .profile:
            return "보관함"
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
