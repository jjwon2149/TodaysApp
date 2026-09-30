import XCTest
@testable import DailyFrame

@MainActor
final class HomeLoadStateTests: DomainTestFixture {
    func testInitialReadFailureIsNotPresentedAsEmptyAndRetryRecovers() async throws {
        let provider = makeDateProvider(now: "2026-09-30")
        try corruptStore(at: temporaryDirectory)
        let viewModel = makeHomeViewModel(dateProvider: provider)

        await viewModel.load()

        XCTAssertEqual(viewModel.loadState, .failed)
        XCTAssertTrue(viewModel.shouldShowFullLoadError)
        XCTAssertFalse(viewModel.hasAnyLoadedData)
        XCTAssertFalse(viewModel.hasLoadedTodayEntry)
        XCTAssertFalse(viewModel.hasLoadedStreak)
        XCTAssertFalse(viewModel.hasLoadedMonthStats)
        XCTAssertFalse(viewModel.canPresentEntryEditor)

        try await seed(entries: [entry("2026-09-30")])
        await viewModel.load()

        XCTAssertEqual(viewModel.loadState, .loaded)
        XCTAssertFalse(viewModel.shouldShowFullLoadError)
        XCTAssertEqual(viewModel.todayEntry?.localDateString, "2026-09-30")
        XCTAssertTrue(viewModel.canPresentEntryEditor)
    }

    func testFailedRefreshPreservesLastGoodDataButBlocksEditorUntilTodayIsConfirmed() async throws {
        let provider = makeDateProvider(now: "2026-09-30")
        try await seed(
            entries: [entry("2026-09-30", memo: "kept")],
            streakState: StreakState(
                currentStreak: 4,
                longestStreak: 7,
                lastCompletedLocalDateString: "2026-09-30",
                freezeCount: 2
            )
        )
        let viewModel = makeHomeViewModel(dateProvider: provider)
        await viewModel.load()

        XCTAssertEqual(viewModel.loadState, .loaded)
        XCTAssertEqual(viewModel.currentStreak, 4)
        XCTAssertEqual(viewModel.todayEntry?.memo, "kept")

        try corruptStore(at: temporaryDirectory)
        await viewModel.load()

        XCTAssertEqual(viewModel.loadState, .failed)
        XCTAssertTrue(viewModel.shouldShowPartialLoadError)
        XCTAssertFalse(viewModel.shouldShowFullLoadError)
        XCTAssertEqual(viewModel.currentStreak, 4)
        XCTAssertEqual(viewModel.todayEntry?.memo, "kept")
        XCTAssertEqual(viewModel.recentEntries.first?.memo, "kept")
        XCTAssertFalse(viewModel.canPresentEntryEditor)

        try await seed(entries: [entry("2026-09-30", memo: "recovered")])
        await viewModel.load()

        XCTAssertEqual(viewModel.loadState, .loaded)
        XCTAssertEqual(viewModel.todayEntry?.memo, "recovered")
        XCTAssertTrue(viewModel.canPresentEntryEditor)
    }

    func testOneFailedSourceProducesPartialSuccessAndKeepsConfirmedTodayRouteAvailable() async throws {
        let provider = makeDateProvider(now: "2026-09-30")
        try await seed(entries: [entry("2026-09-29")])

        let failedMissionDirectory = temporaryDirectory.appending(path: "FailedMission")
        try corruptStore(at: failedMissionDirectory)
        let failedMissionStore = PersistenceStore(baseDirectoryURL: failedMissionDirectory)
        let failedMissionService = MissionService(
            repository: MissionRepository(store: failedMissionStore),
            dateProvider: provider
        )
        let viewModel = HomeViewModel(
            entryRepository: entryRepository,
            streakService: makeStreakService(dateProvider: provider),
            missionService: failedMissionService,
            dateProvider: provider
        )

        await viewModel.load()

        XCTAssertEqual(viewModel.loadState, .partialFailure)
        XCTAssertTrue(viewModel.shouldShowPartialLoadError)
        XCTAssertEqual(viewModel.missionLoadState, .failed)
        XCTAssertEqual(viewModel.todayEntryLoadState, .loaded)
        XCTAssertNil(viewModel.todayEntry)
        XCTAssertTrue(viewModel.hasLoadedTodayEntry)
        XCTAssertTrue(viewModel.canPresentEntryEditor)
    }

    func testDateRolloverFailureDoesNotTreatCachedYesterdayEntryAsToday() async throws {
        var now = localDate("2026-09-30")
        let provider = DateProvider(now: { now }, timeZone: seoulTimeZone)
        try await seed(entries: [entry("2026-09-30", memo: "yesterday")])
        let viewModel = makeHomeViewModel(dateProvider: provider)

        await viewModel.load()

        XCTAssertTrue(viewModel.hasLoadedTodayEntry)
        XCTAssertTrue(viewModel.canPresentEntryEditor)
        XCTAssertTrue(viewModel.isTodayMissionCompleted)

        now = localDate("2026-10-01")
        try corruptStore(at: temporaryDirectory)
        await viewModel.load()

        XCTAssertEqual(viewModel.loadState, .failed)
        XCTAssertEqual(viewModel.todayEntry?.localDateString, "2026-09-30")
        XCTAssertFalse(viewModel.hasLoadedTodayEntry)
        XCTAssertFalse(viewModel.hasLoadedMission)
        XCTAssertFalse(viewModel.hasLoadedMonthStats)
        XCTAssertFalse(viewModel.isTodayMissionCompleted)
        XCTAssertFalse(viewModel.canPresentEntryEditor)
    }

    private func makeHomeViewModel(dateProvider: DateProvider) -> HomeViewModel {
        HomeViewModel(
            entryRepository: entryRepository,
            streakService: makeStreakService(dateProvider: dateProvider),
            missionService: makeMissionService(dateProvider: dateProvider),
            dateProvider: dateProvider
        )
    }

    private func corruptStore(at directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("not valid json".utf8).write(
            to: directory.appending(path: "app-state.json"),
            options: .atomic
        )
    }
}
