import XCTest
@testable import DailyFrame

@MainActor
final class HomeProfileStreakContractTests: DomainTestFixture {
    func testProfileFirstThenHomeExposeSameEvaluatedFreezeState() async throws {
        let provider = makeDateProvider(now: "2026-05-07")
        let streakService = makeStreakService(dateProvider: provider)
        let missionService = makeMissionService(dateProvider: provider)

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

        let profileViewModel = ProfileViewModel(
            entryRepository: entryRepository,
            streakService: streakService,
            streakStateRepository: streakRepository,
            appSettingsRepository: settingsRepository,
            dateProvider: provider
        )

        await profileViewModel.load()

        XCTAssertEqual(profileViewModel.currentStreak, 3)
        XCTAssertEqual(profileViewModel.longestStreak, 3)
        XCTAssertEqual(profileViewModel.freezeCount, 0)
        XCTAssertEqual(profileViewModel.latestFreezeUsage?.protectedLocalDateString, "2026-05-06")
        XCTAssertNotNil(profileViewModel.freezeNoticeText)

        let homeViewModel = HomeViewModel(
            entryRepository: entryRepository,
            streakService: streakService,
            missionService: missionService,
            dateProvider: provider
        )

        await homeViewModel.load()

        XCTAssertEqual(homeViewModel.currentStreak, profileViewModel.currentStreak)
        XCTAssertEqual(homeViewModel.longestStreak, profileViewModel.longestStreak)
        XCTAssertEqual(homeViewModel.freezeCount, profileViewModel.freezeCount)
        XCTAssertEqual(homeViewModel.latestFreezeUsage?.protectedLocalDateString, "2026-05-06")
        XCTAssertNotNil(homeViewModel.freezeNoticeText)
    }

    func testHomeFirstThenProfileExposeSameEvaluatedFreezeState() async throws {
        let provider = makeDateProvider(now: "2026-05-07")
        let streakService = makeStreakService(dateProvider: provider)
        let missionService = makeMissionService(dateProvider: provider)

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

        let homeViewModel = HomeViewModel(
            entryRepository: entryRepository,
            streakService: streakService,
            missionService: missionService,
            dateProvider: provider
        )

        await homeViewModel.load()

        XCTAssertEqual(homeViewModel.currentStreak, 3)
        XCTAssertEqual(homeViewModel.longestStreak, 3)
        XCTAssertEqual(homeViewModel.freezeCount, 0)
        XCTAssertEqual(homeViewModel.latestFreezeUsage?.protectedLocalDateString, "2026-05-06")
        XCTAssertNotNil(homeViewModel.freezeNoticeText)

        let profileViewModel = ProfileViewModel(
            entryRepository: entryRepository,
            streakService: streakService,
            streakStateRepository: streakRepository,
            appSettingsRepository: settingsRepository,
            dateProvider: provider
        )

        await profileViewModel.load()

        XCTAssertEqual(profileViewModel.currentStreak, homeViewModel.currentStreak)
        XCTAssertEqual(profileViewModel.longestStreak, homeViewModel.longestStreak)
        XCTAssertEqual(profileViewModel.freezeCount, homeViewModel.freezeCount)
        XCTAssertEqual(profileViewModel.latestFreezeUsage?.protectedLocalDateString, "2026-05-06")
        XCTAssertNotNil(profileViewModel.freezeNoticeText)
    }

    func testHomeDoesNotAutoCompleteMissionWhenNoTodayEntryExists() async throws {
        let provider = makeDateProvider(now: "2026-05-07")
        let streakService = makeStreakService(dateProvider: provider)
        let missionService = makeMissionService(dateProvider: provider)

        try await seed()

        let homeViewModel = HomeViewModel(
            entryRepository: entryRepository,
            streakService: streakService,
            missionService: missionService,
            dateProvider: provider
        )

        await homeViewModel.load()

        XCTAssertEqual(homeViewModel.todayMission?.localDateString, "2026-05-07")
        XCTAssertEqual(homeViewModel.isTodayMissionCompleted, false)
    }
}
