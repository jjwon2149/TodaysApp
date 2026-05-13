import XCTest
@testable import DailyFrame

class DomainTestFixture: XCTestCase {
    var temporaryDirectory: URL!
    var store: PersistenceStore!
    var entryRepository: EntryRepository!
    var streakRepository: StreakStateRepository!
    var settingsRepository: AppSettingsRepository!
    var missionRepository: MissionRepository!

    let seoulTimeZone = TimeZone(identifier: "Asia/Seoul")!
    let losAngelesTimeZone = TimeZone(identifier: "America/Los_Angeles")!

    override func setUp() async throws {
        try await super.setUp()

        temporaryDirectory = FileManager.default.temporaryDirectory
            .appending(path: "DailyFrameTests-\(UUID().uuidString)")
        store = PersistenceStore(baseDirectoryURL: temporaryDirectory)
        entryRepository = EntryRepository(store: store)
        streakRepository = StreakStateRepository(store: store)
        settingsRepository = AppSettingsRepository(store: store)
        missionRepository = MissionRepository(store: store)
    }

    override func tearDown() async throws {
        if let temporaryDirectory {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }

        missionRepository = nil
        settingsRepository = nil
        streakRepository = nil
        entryRepository = nil
        store = nil
        temporaryDirectory = nil

        try await super.tearDown()
    }

    func makeDateProvider(
        now localDateString: String,
        timeZone: TimeZone? = nil
    ) -> DateProvider {
        let timeZone = timeZone ?? seoulTimeZone
        let now = localDate(localDateString, timeZone: timeZone)
        return DateProvider(now: { now }, timeZone: timeZone)
    }

    func makeDateProvider(
        instant: Date,
        timeZone: TimeZone
    ) -> DateProvider {
        DateProvider(now: { instant }, timeZone: timeZone)
    }

    func makeStreakService(dateProvider: DateProvider) -> StreakService {
        StreakService(
            repository: streakRepository,
            entryRepository: entryRepository,
            appSettingsRepository: settingsRepository,
            dateProvider: dateProvider
        )
    }

    func makeMissionService(dateProvider: DateProvider) -> MissionService {
        MissionService(repository: missionRepository, dateProvider: dateProvider)
    }

    func seed(
        entries: [DailyPhotoEntry] = [],
        streakState: StreakState = StreakState(),
        settings: AppSettings = AppSettings(),
        missionHistory: [DailyMission] = []
    ) async throws {
        let snapshot = AppStateSnapshot(
            userProfile: UserProfile(),
            entries: entries,
            streakState: streakState,
            settings: settings,
            missionHistory: missionHistory
        )

        try await store.save(snapshot)
    }

    func entry(
        _ localDateString: String,
        timeZone: TimeZone? = nil,
        memo: String? = nil,
        isDeleted: Bool = false
    ) -> DailyPhotoEntry {
        let timeZone = timeZone ?? seoulTimeZone
        let createdAt = localDate(localDateString, timeZone: timeZone)

        return DailyPhotoEntry(
            localDateString: localDateString,
            createdAtUTC: createdAt,
            updatedAtUTC: createdAt,
            timezoneIdentifier: timeZone.identifier,
            timezoneOffsetMinutes: Int(timeZone.secondsFromGMT(for: createdAt) / 60),
            imageLocalPath: "/tmp/\(localDateString).jpg",
            memo: memo,
            sourceType: "test",
            isDeleted: isDeleted
        )
    }

    func mission(
        _ localDateString: String,
        completedAtUTC: Date? = nil
    ) -> DailyMission {
        DailyMission(
            id: "\(localDateString)-test",
            localDateString: localDateString,
            templateID: "today-scene",
            title: "mission.today_scene.title",
            prompt: "mission.today_scene.prompt",
            category: "mission.category.record",
            symbolName: "camera.aperture",
            createdAtUTC: localDate(localDateString, timeZone: seoulTimeZone),
            completedAtUTC: completedAtUTC
        )
    }

    func localDate(_ localDateString: String, timeZone: TimeZone? = nil) -> Date {
        let timeZone = timeZone ?? seoulTimeZone
        let provider = DateProvider(timeZone: timeZone)

        guard let date = provider.date(from: localDateString) else {
            XCTFail("Invalid local date: \(localDateString)")
            return Date(timeIntervalSince1970: 0)
        }

        return date
    }

    func instant(_ iso8601String: String) -> Date {
        let formatter = ISO8601DateFormatter()

        guard let date = formatter.date(from: iso8601String) else {
            XCTFail("Invalid ISO8601 instant: \(iso8601String)")
            return Date(timeIntervalSince1970: 0)
        }

        return date
    }
}
