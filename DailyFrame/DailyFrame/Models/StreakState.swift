import Foundation

struct StreakState: Codable, Identifiable {
    var id: UUID
    var currentStreak: Int
    var longestStreak: Int
    var lastCompletedLocalDateString: String?
    var freezeCount: Int
    var lastAutoAppliedFreezeLocalDateString: String?
    var lastEvaluatedAtUTC: Date?
    var lastKnownTimezoneIdentifier: String

    init(
        id: UUID = UUID(),
        currentStreak: Int = 0,
        longestStreak: Int = 0,
        lastCompletedLocalDateString: String? = nil,
        freezeCount: Int = 1,
        lastAutoAppliedFreezeLocalDateString: String? = nil,
        lastEvaluatedAtUTC: Date? = nil,
        lastKnownTimezoneIdentifier: String = TimeZone.current.identifier
    ) {
        self.id = id
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.lastCompletedLocalDateString = lastCompletedLocalDateString
        self.freezeCount = freezeCount
        self.lastAutoAppliedFreezeLocalDateString = lastAutoAppliedFreezeLocalDateString
        self.lastEvaluatedAtUTC = lastEvaluatedAtUTC
        self.lastKnownTimezoneIdentifier = lastKnownTimezoneIdentifier
    }
}
