import XCTest
@testable import DailyFrame

final class StreakServiceTests: XCTestCase {
    private var temporaryDirectory: URL!
    private var store: PersistenceStore!
    private var entryRepository: EntryRepository!
    private var streakRepository: StreakStateRepository!
    private var settingsRepository: AppSettingsRepository!
    private var streakService: StreakService!

    override func setUp() async throws {
        try await super.setUp()

        temporaryDirectory = FileManager.default.temporaryDirectory
            .appending(path: "DailyFrameTests-\(UUID().uuidString)")
        store = PersistenceStore(baseDirectoryURL: temporaryDirectory)
        entryRepository = EntryRepository(store: store)
        streakRepository = StreakStateRepository(store: store)
        settingsRepository = AppSettingsRepository(store: store)
        streakService = StreakService(
            repository: streakRepository,
            entryRepository: entryRepository,
            appSettingsRepository: settingsRepository
        )
    }

    override func tearDown() async throws {
        if let temporaryDirectory {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }

        streakService = nil
        settingsRepository = nil
        streakRepository = nil
        entryRepository = nil
        store = nil
        temporaryDirectory = nil

        try await super.tearDown()
    }

    func testEvaluateUsesFreezeForD2GapAndIsSameDayIdempotent() async throws {
        try await seed(
            entries: [
                entry("2026-05-03"),
                entry("2026-05-04"),
                entry("2026-05-05")
            ],
            streakState: StreakState(
                currentStreak: 3,
                longestStreak: 3,
                lastCompletedLocalDateString: "2026-05-05",
                freezeCount: 2
            )
        )

        let evaluated = try await streakService.evaluateMissedYesterdayIfNeeded(now: date("2026-05-07"))

        XCTAssertEqual(evaluated.currentStreak, 3)
        XCTAssertEqual(evaluated.longestStreak, 3)
        XCTAssertEqual(evaluated.freezeCount, 1)
        XCTAssertEqual(evaluated.lastCompletedLocalDateString, "2026-05-06")
        XCTAssertEqual(evaluated.lastAutoAppliedFreezeLocalDateString, "2026-05-06")

        let evaluatedAgain = try await streakService.evaluateMissedYesterdayIfNeeded(now: date("2026-05-07"))

        XCTAssertEqual(evaluatedAgain.freezeCount, 1)
        XCTAssertEqual(evaluatedAgain.lastCompletedLocalDateString, "2026-05-06")
    }

    func testEvaluateResetsCurrentStreakForD2GapWithoutFreeze() async throws {
        try await seed(
            entries: [
                entry("2026-05-03"),
                entry("2026-05-04"),
                entry("2026-05-05")
            ],
            streakState: StreakState(
                currentStreak: 3,
                longestStreak: 3,
                lastCompletedLocalDateString: "2026-05-05",
                freezeCount: 0
            )
        )

        let evaluated = try await streakService.evaluateMissedYesterdayIfNeeded(now: date("2026-05-07"))

        XCTAssertEqual(evaluated.currentStreak, 0)
        XCTAssertEqual(evaluated.longestStreak, 3)
        XCTAssertEqual(evaluated.freezeCount, 0)
        XCTAssertEqual(evaluated.lastCompletedLocalDateString, "2026-05-05")
    }

    @MainActor
    func testProfileLoadEvaluatesStreakWithoutOpeningHome() async throws {
        try await seed(
            entries: [
                entry("2026-05-03"),
                entry("2026-05-04"),
                entry("2026-05-05")
            ],
            streakState: StreakState(
                currentStreak: 3,
                longestStreak: 3,
                lastCompletedLocalDateString: "2026-05-05",
                freezeCount: 1
            )
        )

        let testNow = date("2026-05-07")
        let viewModel = ProfileViewModel(
            entryRepository: entryRepository,
            streakService: streakService,
            streakStateRepository: streakRepository,
            appSettingsRepository: settingsRepository,
            nowProvider: { testNow }
        )

        await viewModel.load()

        XCTAssertEqual(viewModel.currentStreak, 3)
        XCTAssertEqual(viewModel.longestStreak, 3)

        let state = try await streakRepository.fetchPrimaryState()
        XCTAssertEqual(state.freezeCount, 0)
        XCTAssertEqual(state.lastCompletedLocalDateString, "2026-05-06")
    }

    func testRebuildAppliesMissedYesterdayPolicyAfterSoftDelete() async throws {
        try await seed(
            entries: [
                entry("2026-05-05")
            ],
            streakState: StreakState(
                currentStreak: 1,
                longestStreak: 1,
                lastCompletedLocalDateString: "2026-05-05",
                freezeCount: 1,
                lastEvaluatedAtUTC: date("2026-05-07")
            )
        )

        let rebuilt = try await streakService.rebuildFromActiveEntries(now: date("2026-05-07"))

        XCTAssertEqual(rebuilt.currentStreak, 1)
        XCTAssertEqual(rebuilt.longestStreak, 1)
        XCTAssertEqual(rebuilt.freezeCount, 0)
        XCTAssertEqual(rebuilt.lastCompletedLocalDateString, "2026-05-06")
        XCTAssertEqual(rebuilt.lastAutoAppliedFreezeLocalDateString, "2026-05-06")
    }

    func testRebuildDoesNotConsumeSecondFreezeWhenSameDayFreezeWasAlreadyApplied() async throws {
        try await seed(
            entries: [
                entry("2026-05-05")
            ],
            streakState: StreakState(
                currentStreak: 1,
                longestStreak: 1,
                lastCompletedLocalDateString: "2026-05-06",
                freezeCount: 1,
                lastAutoAppliedFreezeLocalDateString: "2026-05-06",
                lastEvaluatedAtUTC: date("2026-05-07")
            )
        )

        let rebuilt = try await streakService.rebuildFromActiveEntries(now: date("2026-05-07"))

        XCTAssertEqual(rebuilt.currentStreak, 1)
        XCTAssertEqual(rebuilt.longestStreak, 1)
        XCTAssertEqual(rebuilt.freezeCount, 1)
        XCTAssertEqual(rebuilt.lastCompletedLocalDateString, "2026-05-06")
        XCTAssertEqual(rebuilt.lastAutoAppliedFreezeLocalDateString, "2026-05-06")
    }

    func testWidgetSnapshotClearsTodayEntryAfterMidnightButKeepsActiveStreak() {
        let snapshot = DailyFrameWidgetSnapshot(
            generatedAtUTC: date("2026-05-05"),
            localDateString: "2026-05-05",
            hasTodayEntry: true,
            currentStreak: 3,
            longestStreak: 3,
            freezeCount: 1,
            lastCompletedLocalDateString: "2026-05-05"
        )

        XCTAssertFalse(snapshot.hasEntry(on: date("2026-05-06")))
        XCTAssertEqual(snapshot.displayCurrentStreak(on: date("2026-05-06")), 3)
    }

    func testWidgetSnapshotDoesNotShowExpiredStreakFromStaleData() {
        let snapshot = DailyFrameWidgetSnapshot(
            generatedAtUTC: date("2026-05-05"),
            localDateString: "2026-05-05",
            hasTodayEntry: true,
            currentStreak: 3,
            longestStreak: 3,
            freezeCount: 0,
            lastCompletedLocalDateString: "2026-05-05"
        )

        XCTAssertFalse(snapshot.hasEntry(on: date("2026-05-07")))
        XCTAssertEqual(snapshot.displayCurrentStreak(on: date("2026-05-07")), 0)
    }

    private func seed(
        entries: [DailyPhotoEntry],
        streakState: StreakState,
        settings: AppSettings = AppSettings()
    ) async throws {
        let snapshot = AppStateSnapshot(
            userProfile: UserProfile(),
            entries: entries,
            streakState: streakState,
            settings: settings,
            missionHistory: []
        )

        try await store.save(snapshot)
    }

    private func entry(_ localDateString: String) -> DailyPhotoEntry {
        DailyPhotoEntry(
            localDateString: localDateString,
            imageLocalPath: "/tmp/\(localDateString).jpg",
            sourceType: "test"
        )
    }

    private func date(_ localDateString: String) -> Date {
        guard let date = DailyFrameDateFormatter.date(from: localDateString) else {
            XCTFail("Invalid test date: \(localDateString)")
            return Date(timeIntervalSince1970: 0)
        }

        return date
    }
}
