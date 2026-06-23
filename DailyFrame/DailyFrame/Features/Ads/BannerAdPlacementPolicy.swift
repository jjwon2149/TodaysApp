enum BannerAdPlacementPolicy {
    enum Surface: CaseIterable {
        case home
        case calendar
        case profile
        case entryEditor
        case cameraCapture
        case photoPicker
        case saveCompletion
        case widget
        case immediateDeepLink
    }

    static func permitsBanner(on surface: Surface) -> Bool {
        switch surface {
        case .profile:
            return true
        case .home,
             .calendar,
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
