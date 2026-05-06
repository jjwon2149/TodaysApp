import Foundation

struct UserProfile: Codable, Identifiable {
    var id: UUID
    var nickname: String?
    var createdAtUTC: Date
    var onboardingCompleted: Bool
    var timezoneIdentifier: String
    var premiumStatus: String
    var currentXP: Int

    init(
        id: UUID = UUID(),
        nickname: String? = nil,
        createdAtUTC: Date = .now,
        onboardingCompleted: Bool = false,
        timezoneIdentifier: String = TimeZone.current.identifier,
        premiumStatus: String = "free",
        currentXP: Int = 0
    ) {
        self.id = id
        self.nickname = nickname
        self.createdAtUTC = createdAtUTC
        self.onboardingCompleted = onboardingCompleted
        self.timezoneIdentifier = timezoneIdentifier
        self.premiumStatus = premiumStatus
        self.currentXP = currentXP
    }
}
