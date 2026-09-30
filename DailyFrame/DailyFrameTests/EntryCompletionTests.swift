import UIKit
import XCTest
@testable import DailyFrame

@MainActor
final class EntryCompletionTests: DomainTestFixture {
    private var entriesDirectory: URL!
    private var imageStorageService: ImageStorageService!
    private var dateProvider: DateProvider!

    override func setUp() async throws {
        try await super.setUp()

        entriesDirectory = temporaryDirectory.appending(path: "Entries")
        try FileManager.default.createDirectory(at: entriesDirectory, withIntermediateDirectories: true)
        imageStorageService = ImageStorageService(entriesDirectoryURL: entriesDirectory)
        dateProvider = makeDateProvider(now: "2026-09-30")
    }

    override func tearDown() async throws {
        dateProvider = nil
        imageStorageService = nil
        entriesDirectory = nil

        try await super.tearDown()
    }

    func testNewSaveReportsCreatedOutcomeAndConfirmedPersistedStreak() async throws {
        try await seed(streakState: StreakState(currentStreak: 3, longestStreak: 3, lastCompletedLocalDateString: "2026-09-29"))
        let viewModel = makeViewModel()
        viewModel.loadCapturedImage(makeTestImage())

        let saved = await viewModel.saveEntry()

        let summary = try XCTUnwrap(viewModel.completionSummary)
        let persistedStreak = try await streakRepository.fetchPrimaryState()
        XCTAssertTrue(saved)
        XCTAssertEqual(summary.outcome, .created)
        XCTAssertEqual(summary.confirmedCurrentStreak, persistedStreak.currentStreak)
        XCTAssertEqual(summary.confirmedCurrentStreak, 4)
        XCTAssertEqual(summary.missionCompleted, true)
        XCTAssertNotNil(summary.missionTitle)
    }

    func testEditingEntryReportsUpdatedOutcomeWithoutNewAchievement() async throws {
        let existingEntry = try await makeExistingEntry(localDateString: "2026-09-30")
        let originalStreak = StreakState(currentStreak: 7, longestStreak: 9, lastCompletedLocalDateString: "2026-09-30")
        try await seed(entries: [existingEntry], streakState: originalStreak)
        let viewModel = makeViewModel(existingEntry: existingEntry)
        viewModel.memo = "Updated memo"

        let saved = await viewModel.saveEntry()

        let summary = try XCTUnwrap(viewModel.completionSummary)
        let persistedStreak = try await streakRepository.fetchPrimaryState()
        let updatedEntry = try await entryRepository.fetchEntry(for: "2026-09-30")
        let missionHistory = try await missionRepository.fetchAllMissions()
        XCTAssertTrue(saved)
        XCTAssertEqual(summary.outcome, .updated)
        XCTAssertNil(summary.confirmedCurrentStreak)
        XCTAssertNil(summary.missionTitle)
        XCTAssertNil(summary.missionCompleted)
        XCTAssertEqual(persistedStreak.currentStreak, originalStreak.currentStreak)
        XCTAssertEqual(updatedEntry?.memo, "Updated memo")
        XCTAssertTrue(missionHistory.isEmpty)
    }

    func testStreakRetrievalFailureKeepsSavedConfirmationWithoutNumericClaim() async throws {
        let viewModel = makeViewModel(streakStateFetcher: {
            throw CocoaError(.fileReadCorruptFile)
        })
        viewModel.loadCapturedImage(makeTestImage())

        let saved = await viewModel.saveEntry()

        let summary = try XCTUnwrap(viewModel.completionSummary)
        let entries = try await entryRepository.fetchAllActiveEntries()
        XCTAssertTrue(saved)
        XCTAssertEqual(summary.outcome, .created)
        XCTAssertNil(summary.confirmedCurrentStreak)
        XCTAssertEqual(summary.returnMessage, L10n.string("editor.completion.saved_message"))
        XCTAssertEqual(entries.count, 1)
    }

    func testFailureDoesNotOverwriteConcurrentReplacementForSavedDay() async throws {
        let concurrentEntry = DailyPhotoEntry(
            localDateString: "2026-09-30",
            imageLocalPath: "synced-image.jpg",
            memo: "Synced elsewhere",
            sourceType: "sync"
        )
        let viewModel = makeViewModel(streakCompletionRecorder: { [entryRepository] _ in
            try await entryRepository?.upsert(concurrentEntry)
            throw CocoaError(.fileWriteUnknown)
        })
        viewModel.loadCapturedImage(makeTestImage())

        let saved = await viewModel.saveEntry()

        let persistedEntry = try await entryRepository.fetchEntry(for: "2026-09-30")
        XCTAssertFalse(saved)
        XCTAssertEqual(persistedEntry?.id, concurrentEntry.id)
        XCTAssertEqual(persistedEntry?.memo, "Synced elsewhere")
        XCTAssertEqual(persistedEntry?.sourceType, "sync")
    }

    func testStreakWriteFailureRollsBackEntryAndMissionCompletionTogether() async throws {
        let incompleteMission = mission("2026-09-30")
        try await seed(missionHistory: [incompleteMission])
        let viewModel = makeViewModel(streakCompletionRecorder: { _ in
            throw CocoaError(.fileWriteUnknown)
        })
        viewModel.loadCapturedImage(makeTestImage())

        let saved = await viewModel.saveEntry()

        let entries = try await entryRepository.fetchAllActiveEntries()
        let persistedMission = try await missionRepository.fetchMission(for: "2026-09-30")
        let restoredMission = try XCTUnwrap(persistedMission)
        XCTAssertFalse(saved)
        XCTAssertTrue(entries.isEmpty)
        XCTAssertEqual(restoredMission.id, incompleteMission.id)
        XCTAssertFalse(restoredMission.isCompleted)
    }

    private func makeViewModel(
        existingEntry: DailyPhotoEntry? = nil,
        streakCompletionRecorder: ((String) async throws -> Void)? = nil,
        streakStateFetcher: (() async throws -> StreakState)? = nil
    ) -> EntryEditorViewModel {
        EntryEditorViewModel(
            existingEntry: existingEntry,
            entryRepository: entryRepository,
            imageStorageService: imageStorageService,
            streakService: makeStreakService(dateProvider: dateProvider),
            streakStateRepository: streakRepository,
            missionService: makeMissionService(dateProvider: dateProvider),
            missionRepository: missionRepository,
            streakCompletionRecorder: streakCompletionRecorder,
            streakStateFetcher: streakStateFetcher,
            dateProvider: dateProvider,
            postSaveEffects: {}
        )
    }

    private func makeExistingEntry(localDateString: String) async throws -> DailyPhotoEntry {
        let fileNames = imageStorageService.makeEntryImageFileNames(localDateString: localDateString)
        let storedImage = try imageStorageService.saveEntryImageData(
            try XCTUnwrap(makeTestImage().jpegData(compressionQuality: 1)),
            imageFileName: fileNames.imageFileName,
            thumbnailFileName: fileNames.thumbnailFileName
        )
        return DailyPhotoEntry(
            localDateString: localDateString,
            imageLocalPath: try imageStorageService.mediaReference(for: storedImage.imageURL),
            thumbnailLocalPath: try imageStorageService.mediaReference(for: storedImage.thumbnailURL),
            memo: "Original memo",
            missionId: "existing-mission",
            missionCompleted: true,
            sourceType: "camera"
        )
    }

    private func makeTestImage() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 24, height: 24)).image { context in
            UIColor.systemIndigo.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 24, height: 24))
        }
    }
}
