enum BannerAdPlacementPolicy {
    enum Surface: CaseIterable {
        case home
        case calendar
        case profile
        case onboarding
        case entryDetail
        case entryEditor
        case cameraCapture
        case photoPicker
        case saveCompletion
        case widget
        case immediateDeepLink
    }

    static func permitsBanner(on surface: Surface) -> Bool {
        switch surface {
        case .home, .calendar, .profile:
            return true
        case .onboarding,
             .entryDetail,
             .entryEditor,
             .cameraCapture,
             .photoPicker,
             .saveCompletion,
             .widget,
             .immediateDeepLink:
            return false
        }
    }
}
