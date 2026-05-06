import Foundation

struct DailyPhotoEntry: Codable, Identifiable {
    var id: UUID
    var localDateString: String
    var createdAtUTC: Date
    var updatedAtUTC: Date
    var timezoneIdentifier: String
    var timezoneOffsetMinutes: Int
    var imageLocalPath: String
    var thumbnailLocalPath: String?
    var memo: String?
    var moodCode: String?
    var missionId: String?
    var missionCompleted: Bool
    var sourceType: String
    var isDeleted: Bool

    init(
        id: UUID = UUID(),
        localDateString: String,
        createdAtUTC: Date = .now,
        updatedAtUTC: Date = .now,
        timezoneIdentifier: String = TimeZone.current.identifier,
        timezoneOffsetMinutes: Int = Int(TimeZone.current.secondsFromGMT() / 60),
        imageLocalPath: String,
        thumbnailLocalPath: String? = nil,
        memo: String? = nil,
        moodCode: String? = nil,
        missionId: String? = nil,
        missionCompleted: Bool = false,
        sourceType: String,
        isDeleted: Bool = false
    ) {
        self.id = id
        self.localDateString = localDateString
        self.createdAtUTC = createdAtUTC
        self.updatedAtUTC = updatedAtUTC
        self.timezoneIdentifier = timezoneIdentifier
        self.timezoneOffsetMinutes = timezoneOffsetMinutes
        self.imageLocalPath = imageLocalPath
        self.thumbnailLocalPath = thumbnailLocalPath
        self.memo = memo
        self.moodCode = moodCode
        self.missionId = missionId
        self.missionCompleted = missionCompleted
        self.sourceType = sourceType
        self.isDeleted = isDeleted
    }
}
