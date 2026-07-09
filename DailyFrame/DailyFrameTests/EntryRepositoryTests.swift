import XCTest
import UIKit
@testable import DailyFrame

final class EntryRepositoryTests: DomainTestFixture {
    func testUpsertReplacesSameLocalDateAndFetchesActiveEntriesSorted() async throws {
        try await seed(entries: [entry("2026-05-06", memo: "first")])

        try await entryRepository.upsert(entry("2026-05-05", memo: "older"))
        try await entryRepository.upsert(entry("2026-05-06", memo: "replacement"))
        try await entryRepository.upsert(entry("2026-05-07", memo: "newer"))

        let entries = try await entryRepository.fetchAllActiveEntries()

        XCTAssertEqual(entries.map(\.localDateString), [
            "2026-05-05",
            "2026-05-06",
            "2026-05-07"
        ])
        XCTAssertEqual(entries.first { $0.localDateString == "2026-05-06" }?.memo, "replacement")
    }

    func testSoftDeleteExcludesEntryFromActiveFetchesAndPreservesTombstone() async throws {
        try await seed(entries: [
            entry("2026-05-05"),
            entry("2026-05-06"),
            entry("2026-05-07")
        ])

        try await entryRepository.softDelete(localDateString: "2026-05-06")

        let deletedEntry = try await entryRepository.fetchEntry(for: "2026-05-06")
        let activeEntries = try await entryRepository.fetchAllActiveEntries()
        let rawEntries = try await store.load().entries

        XCTAssertNil(deletedEntry)
        XCTAssertEqual(activeEntries.map(\.localDateString), ["2026-05-05", "2026-05-07"])
        XCTAssertEqual(rawEntries.first { $0.localDateString == "2026-05-06" }?.isDeleted, true)
    }

    func testStoredTimezoneMetadataSurvivesLaterTimezonePolicyChanges() async throws {
        let seoulEntry = entry("2026-05-07", timeZone: seoulTimeZone)
        let losAngelesProvider = makeDateProvider(now: "2026-05-06", timeZone: losAngelesTimeZone)

        try await seed(entries: [seoulEntry])

        let fetched = try await entryRepository.fetchEntry(for: "2026-05-07")

        XCTAssertEqual(losAngelesProvider.localDateStringForNow(), "2026-05-06")
        XCTAssertEqual(fetched?.localDateString, "2026-05-07")
        XCTAssertEqual(fetched?.timezoneIdentifier, seoulTimeZone.identifier)
        XCTAssertEqual(fetched?.timezoneOffsetMinutes, 540)
    }
}

@MainActor
final class EntryEditorViewModelTests: DomainTestFixture {
    private var entriesDirectory: URL!
    private var imageStorageService: ImageStorageService!

    override func setUp() async throws {
        try await super.setUp()

        entriesDirectory = temporaryDirectory.appending(path: "Entries")
        try FileManager.default.createDirectory(at: entriesDirectory, withIntermediateDirectories: true)
        imageStorageService = ImageStorageService(entriesDirectoryURL: entriesDirectory)
    }

    override func tearDown() async throws {
        imageStorageService = nil
        entriesDirectory = nil

        try await super.tearDown()
    }

    func testPhotoReadyStatusCopySaysMemoAndMoodAreOptionalInSupportedLocales() throws {
        let expectedFragmentsByLocale = [
            "en": ["memo", "mood", "optional"],
            "ko": ["메모", "기분", "선택"],
            "ja": ["メモ", "気分", "任意"]
        ]

        for (locale, fragments) in expectedFragmentsByLocale {
            let value = try localizedStringValue(
                key: "editor.status.photo_ready",
                locale: locale
            )

            for fragment in fragments {
                XCTAssertTrue(
                    value.localizedStandardContains(fragment),
                    "\(locale) editor.status.photo_ready should include \(fragment), got: \(value)"
                )
            }
        }
    }

    func testCompletionReturnActionsAreLocalizedInSupportedLocales() throws {
        let expectedValuesByLocale = [
            "en": [
                "editor.completion.reminder_action": "Get Tomorrow's Reminder",
                "editor.completion.calendar_action": "View in Calendar",
                "editor.completion.skip_action": "Later"
            ],
            "ko": [
                "editor.completion.reminder_action": "내일 알림 받기",
                "editor.completion.calendar_action": "캘린더에서 보기",
                "editor.completion.skip_action": "나중에"
            ],
            "ja": [
                "editor.completion.reminder_action": "明日の通知を受け取る",
                "editor.completion.calendar_action": "カレンダーで見る",
                "editor.completion.skip_action": "あとで"
            ]
        ]

        for (locale, expectedValues) in expectedValuesByLocale {
            for (key, expectedValue) in expectedValues {
                let value = try localizedStringValue(key: key, locale: locale)

                XCTAssertEqual(value, expectedValue, "\(locale) \(key)")
            }
        }
    }

    func testSaveWithoutPhotoFailsWithRequiredPhotoError() async throws {
        let viewModel = makeViewModel()

        XCTAssertFalse(viewModel.canSave)

        let saved = await viewModel.saveEntry()

        XCTAssertFalse(saved)
        XCTAssertFalse(viewModel.isSaving)
        XCTAssertEqual(viewModel.errorMessage, L10n.string("error.save.no_photo"))
        XCTAssertTrue(viewModel.isShowingErrorAlert)
        let entries = try await entryRepository.fetchAllActiveEntries()
        XCTAssertTrue(entries.isEmpty)
    }

    func testPhotoOnlySavePersistsWithoutMemoOrMood() async throws {
        let viewModel = makeViewModel()
        viewModel.loadCapturedImage(makeTestImage())

        XCTAssertTrue(viewModel.canSave)

        let saved = await viewModel.saveEntry()

        let entries = try await entryRepository.fetchAllActiveEntries()
        let entry = try XCTUnwrap(entries.first)

        XCTAssertTrue(saved)
        XCTAssertEqual(entries.count, 1)
        XCTAssertNil(entry.memo)
        XCTAssertNil(entry.moodCode)
        XCTAssertEqual(entry.sourceType, "camera")
        XCTAssertNotNil(viewModel.completionSummary)
    }

    func testRepeatedSaveCallsWhileSavingCreateOneEntry() async throws {
        let viewModel = makeViewModel()
        viewModel.loadCapturedImage(makeTestImage())

        async let firstSave = viewModel.saveEntry()
        async let secondSave = viewModel.saveEntry()

        let results = await [firstSave, secondSave]
        let entries = try await entryRepository.fetchAllActiveEntries()

        XCTAssertEqual(results.filter { $0 }.count, 1)
        XCTAssertEqual(entries.count, 1)
    }

    private func makeViewModel() -> EntryEditorViewModel {
        EntryEditorViewModel(
            entryRepository: entryRepository,
            imageStorageService: imageStorageService,
            streakService: makeStreakService(dateProvider: makeDateProvider(now: "2026-07-09")),
            streakStateRepository: streakRepository,
            missionService: makeMissionService(dateProvider: makeDateProvider(now: "2026-07-09"))
        )
    }

    private func makeTestImage() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 24, height: 24)).image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 24, height: 24))
        }
    }

    private func localizedStringValue(key: String, locale: String) throws -> String {
        let testsFileURL = URL(fileURLWithPath: #filePath)
        let projectRoot = testsFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let stringsURL = projectRoot
            .appending(path: "DailyFrame")
            .appending(path: "DailyFrame")
            .appending(path: "\(locale).lproj")
            .appending(path: "Localizable.strings")
        let data = try Data(contentsOf: stringsURL)
        let dictionary = try XCTUnwrap(
            PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String]
        )
        let value = try XCTUnwrap(dictionary[key])
        return value
    }
}
