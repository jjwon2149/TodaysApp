import Foundation

enum CloudSyncUnavailableReason: String, Equatable {
    case noAccount
    case restricted
    case couldNotDetermine
    case temporarilyUnavailable
    case unknown
}

enum CloudSyncAccountState: Equatable {
    case available
    case unavailable(CloudSyncUnavailableReason)
}

enum CloudSyncRunTrigger {
    case launch
    case foreground
    case localChange
    case manual
}

struct CloudSyncStatus: Equatable {
    enum State: Equatable {
        case idle
        case syncing
        case synced
        case unavailable(CloudSyncUnavailableReason)
        case failed(String)
    }

    var state: State
    var lastSyncedAtUTC: Date?
    var uploadedEntryCount: Int
    var downloadedEntryCount: Int
    var uploadedMediaCount: Int
    var downloadedMediaCount: Int
    var skippedMediaCount: Int

    static let idle = CloudSyncStatus(
        state: .idle,
        lastSyncedAtUTC: nil,
        uploadedEntryCount: 0,
        downloadedEntryCount: 0,
        uploadedMediaCount: 0,
        downloadedMediaCount: 0,
        skippedMediaCount: 0
    )

    static func syncing(previous: CloudSyncStatus) -> CloudSyncStatus {
        CloudSyncStatus(
            state: .syncing,
            lastSyncedAtUTC: previous.lastSyncedAtUTC,
            uploadedEntryCount: previous.uploadedEntryCount,
            downloadedEntryCount: previous.downloadedEntryCount,
            uploadedMediaCount: previous.uploadedMediaCount,
            downloadedMediaCount: previous.downloadedMediaCount,
            skippedMediaCount: previous.skippedMediaCount
        )
    }
}

enum CloudSyncMediaRole: String, CaseIterable {
    case image
    case thumbnail
}

struct CloudSyncEntryRecord: Equatable {
    let localDateString: String
    let createdAtUTC: Date
    let updatedAtUTC: Date
    let timezoneIdentifier: String
    let timezoneOffsetMinutes: Int
    let memo: String?
    let moodCode: String?
    let missionId: String?
    let missionCompleted: Bool
    let sourceType: String
    let isDeleted: Bool

    init(
        localDateString: String,
        createdAtUTC: Date,
        updatedAtUTC: Date,
        timezoneIdentifier: String,
        timezoneOffsetMinutes: Int,
        memo: String?,
        moodCode: String?,
        missionId: String?,
        missionCompleted: Bool,
        sourceType: String,
        isDeleted: Bool
    ) {
        self.localDateString = localDateString
        self.createdAtUTC = createdAtUTC
        self.updatedAtUTC = updatedAtUTC
        self.timezoneIdentifier = timezoneIdentifier
        self.timezoneOffsetMinutes = timezoneOffsetMinutes
        self.memo = memo
        self.moodCode = moodCode
        self.missionId = missionId
        self.missionCompleted = missionCompleted
        self.sourceType = sourceType
        self.isDeleted = isDeleted
    }

    init(entry: DailyPhotoEntry) {
        self.localDateString = entry.localDateString
        self.createdAtUTC = entry.createdAtUTC
        self.updatedAtUTC = entry.updatedAtUTC
        self.timezoneIdentifier = entry.timezoneIdentifier
        self.timezoneOffsetMinutes = entry.timezoneOffsetMinutes
        self.memo = entry.memo
        self.moodCode = entry.moodCode
        self.missionId = entry.missionId
        self.missionCompleted = entry.missionCompleted
        self.sourceType = entry.sourceType
        self.isDeleted = entry.isDeleted
    }

    func makeLocalEntry(
        preserving existingEntry: DailyPhotoEntry?,
        mediaFileNames: [CloudSyncMediaRole: String]
    ) -> DailyPhotoEntry {
        let imageLocalPath = mediaFileNames[.image]
            ?? existingEntry?.imageLocalPath
            ?? "\(localDateString)-missing.jpg"

        return DailyPhotoEntry(
            id: existingEntry?.id ?? UUID(),
            localDateString: localDateString,
            createdAtUTC: createdAtUTC,
            updatedAtUTC: updatedAtUTC,
            timezoneIdentifier: timezoneIdentifier,
            timezoneOffsetMinutes: timezoneOffsetMinutes,
            imageLocalPath: imageLocalPath,
            thumbnailLocalPath: mediaFileNames[.thumbnail] ?? existingEntry?.thumbnailLocalPath,
            memo: memo,
            moodCode: moodCode,
            missionId: missionId,
            missionCompleted: missionCompleted,
            sourceType: sourceType,
            isDeleted: isDeleted
        )
    }
}

struct CloudSyncMediaAsset: Equatable {
    let localDateString: String
    let role: CloudSyncMediaRole
    let fileName: String
    let updatedAtUTC: Date
    let assetFileURL: URL?
}

protocol CloudSyncRemoteStore {
    func accountState() async throws -> CloudSyncAccountState
    func fetchEntries() async throws -> [CloudSyncEntryRecord]
    func fetchMedia() async throws -> [CloudSyncMediaAsset]
    func save(entry: CloudSyncEntryRecord) async throws
    func save(media: CloudSyncMediaAsset) async throws
}
