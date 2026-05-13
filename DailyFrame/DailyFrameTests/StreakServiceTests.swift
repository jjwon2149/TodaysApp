import UIKit
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

    func testRecordCompletionIgnoresOlderDateThanCurrentAnchor() async throws {
        try await seed(
            entries: [],
            streakState: StreakState(
                currentStreak: 4,
                longestStreak: 5,
                lastCompletedLocalDateString: "2026-05-12"
            )
        )

        try await streakService.recordCompletion(for: "2026-05-09")

        let state = try await streakRepository.fetchPrimaryState()
        XCTAssertEqual(state.currentStreak, 4)
        XCTAssertEqual(state.longestStreak, 5)
        XCTAssertEqual(state.lastCompletedLocalDateString, "2026-05-12")
    }

    @MainActor
    func testExistingEntryMetadataEditDoesNotMoveStreakBackward() async throws {
        let existingEntry = entry(
            "2026-05-09",
            memo: "before",
            moodCode: "평온",
            missionId: "2026-05-09-existing",
            missionCompleted: true,
            thumbnailLocalPath: "/tmp/2026-05-09-thumbnail.jpg"
        )
        try await seed(
            entries: [existingEntry],
            streakState: StreakState(
                currentStreak: 4,
                longestStreak: 4,
                lastCompletedLocalDateString: "2026-05-12"
            ),
            missionHistory: [
                mission("2026-05-09", id: "2026-05-09-existing", completed: true)
            ]
        )
        let viewModel = makeEntryEditorViewModel(existingEntry: existingEntry)

        viewModel.memo = "after"
        viewModel.selectedMood = "좋음"
        let didSave = await viewModel.saveEntry()

        XCTAssertTrue(didSave)
        let state = try await streakRepository.fetchPrimaryState()
        XCTAssertEqual(state.currentStreak, 4)
        XCTAssertEqual(state.lastCompletedLocalDateString, "2026-05-12")

        let fetchedEntry = try await entryRepository.fetchEntry(for: "2026-05-09")
        let savedEntry = try XCTUnwrap(fetchedEntry)
        XCTAssertEqual(savedEntry.memo, "after")
        XCTAssertEqual(savedEntry.moodCode, "좋음")
        XCTAssertEqual(savedEntry.missionId, "2026-05-09-existing")
        XCTAssertTrue(savedEntry.missionCompleted)
    }

    @MainActor
    func testExistingEntryImageReplacementDoesNotMoveStreakBackward() async throws {
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        let oldImageURL = temporaryDirectory.appending(path: "old-image.jpg")
        let oldThumbnailURL = temporaryDirectory.appending(path: "old-thumbnail.jpg")
        try Data("old".utf8).write(to: oldImageURL)
        try Data("old-thumbnail".utf8).write(to: oldThumbnailURL)
        let existingEntry = entry(
            "2026-05-09",
            missionId: "2026-05-09-existing",
            missionCompleted: true,
            imageLocalPath: oldImageURL.path,
            thumbnailLocalPath: oldThumbnailURL.path
        )
        try await seed(
            entries: [existingEntry],
            streakState: StreakState(
                currentStreak: 4,
                longestStreak: 4,
                lastCompletedLocalDateString: "2026-05-12"
            ),
            missionHistory: [
                mission("2026-05-09", id: "2026-05-09-existing", completed: true)
            ]
        )
        let viewModel = makeEntryEditorViewModel(existingEntry: existingEntry)

        viewModel.loadCapturedImage(makeTestImage())
        let didSave = await viewModel.saveEntry()

        XCTAssertTrue(didSave)
        let state = try await streakRepository.fetchPrimaryState()
        XCTAssertEqual(state.currentStreak, 4)
        XCTAssertEqual(state.lastCompletedLocalDateString, "2026-05-12")

        let fetchedEntry = try await entryRepository.fetchEntry(for: "2026-05-09")
        let savedEntry = try XCTUnwrap(fetchedEntry)
        XCTAssertNotEqual(savedEntry.imageLocalPath, oldImageURL.path)
        XCTAssertNotEqual(savedEntry.thumbnailLocalPath, oldThumbnailURL.path)
        XCTAssertEqual(savedEntry.missionId, "2026-05-09-existing")
        XCTAssertTrue(savedEntry.missionCompleted)
    }

    @MainActor
    func testNewTodayEntryStillRecordsStreakCompletion() async throws {
        let todayString = DailyFrameDateFormatter.localDateString(from: .now)
        try await seed(
            entries: [],
            streakState: StreakState(
                currentStreak: 0,
                longestStreak: 0
            )
        )
        let viewModel = makeEntryEditorViewModel()

        viewModel.loadCapturedImage(makeTestImage())
        let didSave = await viewModel.saveEntry()

        XCTAssertTrue(didSave)
        let state = try await streakRepository.fetchPrimaryState()
        XCTAssertEqual(state.currentStreak, 1)
        XCTAssertEqual(state.longestStreak, 1)
        XCTAssertEqual(state.lastCompletedLocalDateString, todayString)

        let fetchedEntry = try await entryRepository.fetchEntry(for: todayString)
        let savedEntry = try XCTUnwrap(fetchedEntry)
        XCTAssertEqual(savedEntry.localDateString, todayString)
        XCTAssertTrue(savedEntry.missionCompleted)
        XCTAssertNotNil(savedEntry.missionId)
    }

    private func seed(
        entries: [DailyPhotoEntry],
        streakState: StreakState,
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

    private func entry(
        _ localDateString: String,
        memo: String? = nil,
        moodCode: String? = nil,
        missionId: String? = nil,
        missionCompleted: Bool = false,
        imageLocalPath: String? = nil,
        thumbnailLocalPath: String? = nil
    ) -> DailyPhotoEntry {
        DailyPhotoEntry(
            localDateString: localDateString,
            imageLocalPath: imageLocalPath ?? "/tmp/\(localDateString).jpg",
            thumbnailLocalPath: thumbnailLocalPath,
            memo: memo,
            moodCode: moodCode,
            missionId: missionId,
            missionCompleted: missionCompleted,
            sourceType: "test"
        )
    }

    private func mission(_ localDateString: String, id: String, completed: Bool) -> DailyMission {
        DailyMission(
            id: id,
            localDateString: localDateString,
            templateID: "today-scene",
            title: "mission.today_scene.title",
            prompt: "mission.today_scene.prompt",
            category: "mission.category.record",
            symbolName: "camera.aperture",
            completedAtUTC: completed ? date(localDateString) : nil
        )
    }

    @MainActor
    private func makeEntryEditorViewModel(existingEntry: DailyPhotoEntry? = nil) -> EntryEditorViewModel {
        EntryEditorViewModel(
            existingEntry: existingEntry,
            entryRepository: entryRepository,
            imageStorageService: ImageStorageService(baseDirectoryURL: temporaryDirectory),
            streakService: streakService,
            streakStateRepository: streakRepository,
            missionService: MissionService(repository: MissionRepository(store: store))
        )
    }

    @MainActor
    private func makeTestImage() -> UIImage {
        let size = CGSize(width: 96, height: 64)
        return UIGraphicsImageRenderer(size: size).image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }

    private func date(_ localDateString: String) -> Date {
        guard let date = DailyFrameDateFormatter.date(from: localDateString) else {
            XCTFail("Invalid test date: \(localDateString)")
            return Date(timeIntervalSince1970: 0)
        }

        return date
    }
}
