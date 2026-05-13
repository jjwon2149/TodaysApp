import Foundation

struct StreakFreezeUsage: Codable, Equatable, Identifiable {
    var id: UUID
    var protectedLocalDateString: String
    var reason: String
    var source: String
    var usedAtUTC: Date
    var timezoneIdentifier: String

    init(
        id: UUID = UUID(),
        protectedLocalDateString: String,
        reason: String = "missed_yesterday",
        source: String,
        usedAtUTC: Date,
        timezoneIdentifier: String
    ) {
        self.id = id
        self.protectedLocalDateString = protectedLocalDateString
        self.reason = reason
        self.source = source
        self.usedAtUTC = usedAtUTC
        self.timezoneIdentifier = timezoneIdentifier
    }
}

struct StreakState: Codable, Identifiable {
    var id: UUID
    var currentStreak: Int
    var longestStreak: Int
    var lastCompletedLocalDateString: String?
    var freezeCount: Int
    var lastAutoAppliedFreezeLocalDateString: String?
    var freezeUsageHistory: [StreakFreezeUsage]
    var lastEvaluatedAtUTC: Date?
    var lastKnownTimezoneIdentifier: String

    var latestFreezeUsage: StreakFreezeUsage? {
        freezeUsageHistory.max { $0.usedAtUTC < $1.usedAtUTC }
    }

    init(
        id: UUID = UUID(),
        currentStreak: Int = 0,
        longestStreak: Int = 0,
        lastCompletedLocalDateString: String? = nil,
        freezeCount: Int = 1,
        lastAutoAppliedFreezeLocalDateString: String? = nil,
        freezeUsageHistory: [StreakFreezeUsage] = [],
        lastEvaluatedAtUTC: Date? = nil,
        lastKnownTimezoneIdentifier: String = TimeZone.current.identifier
    ) {
        self.id = id
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.lastCompletedLocalDateString = lastCompletedLocalDateString
        self.freezeCount = freezeCount
        self.lastAutoAppliedFreezeLocalDateString = lastAutoAppliedFreezeLocalDateString
        self.freezeUsageHistory = freezeUsageHistory
        self.lastEvaluatedAtUTC = lastEvaluatedAtUTC
        self.lastKnownTimezoneIdentifier = lastKnownTimezoneIdentifier
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        currentStreak = try container.decode(Int.self, forKey: .currentStreak)
        longestStreak = try container.decode(Int.self, forKey: .longestStreak)
        lastCompletedLocalDateString = try container.decodeIfPresent(String.self, forKey: .lastCompletedLocalDateString)
        freezeCount = try container.decode(Int.self, forKey: .freezeCount)
        lastAutoAppliedFreezeLocalDateString = try container.decodeIfPresent(String.self, forKey: .lastAutoAppliedFreezeLocalDateString)
        freezeUsageHistory = try container.decodeIfPresent([StreakFreezeUsage].self, forKey: .freezeUsageHistory) ?? []
        lastEvaluatedAtUTC = try container.decodeIfPresent(Date.self, forKey: .lastEvaluatedAtUTC)
        lastKnownTimezoneIdentifier = try container.decodeIfPresent(String.self, forKey: .lastKnownTimezoneIdentifier) ?? TimeZone.current.identifier
    }
}
