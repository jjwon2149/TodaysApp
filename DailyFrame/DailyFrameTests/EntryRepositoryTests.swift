import XCTest
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
