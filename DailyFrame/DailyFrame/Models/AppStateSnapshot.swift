import Foundation

struct AppStateSnapshot: Codable {
    var userProfile: UserProfile
    var entries: [DailyPhotoEntry]
    var streakState: StreakState
    var settings: AppSettings
    var missionHistory: [DailyMission]

    static let initial = AppStateSnapshot(
        userProfile: UserProfile(),
        entries: [],
        streakState: StreakState(),
        settings: AppSettings(),
        missionHistory: []
    )

    init(
        userProfile: UserProfile,
        entries: [DailyPhotoEntry],
        streakState: StreakState,
        settings: AppSettings,
        missionHistory: [DailyMission]
    ) {
        self.userProfile = userProfile
        self.entries = entries
        self.streakState = streakState
        self.settings = settings
        self.missionHistory = missionHistory
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        userProfile = try container.decode(UserProfile.self, forKey: .userProfile)
        entries = try container.decode([DailyPhotoEntry].self, forKey: .entries)
        streakState = try container.decode(StreakState.self, forKey: .streakState)
        settings = try container.decode(AppSettings.self, forKey: .settings)
        missionHistory = try container.decodeIfPresent([DailyMission].self, forKey: .missionHistory) ?? []
    }
}
