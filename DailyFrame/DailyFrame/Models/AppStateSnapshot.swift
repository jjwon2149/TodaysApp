import Foundation

struct AppStateSnapshot: Codable {
    var userProfile: UserProfile
    var entries: [DailyPhotoEntry]
    var streakState: StreakState
    var settings: AppSettings

    static let initial = AppStateSnapshot(
        userProfile: UserProfile(),
        entries: [],
        streakState: StreakState(),
        settings: AppSettings()
    )
}
