import XCTest
@testable import DailyFrame

final class MissionServiceTests: DomainTestFixture {
    func testMissionCreationIsKeyedByRequestedLocalDateNotCurrentTimezoneDate() async throws {
        let now = instant("2026-05-06T16:30:00Z")
        let provider = makeDateProvider(instant: now, timeZone: losAngelesTimeZone)
        let service = makeMissionService(dateProvider: provider)

        try await seed()

        let mission = try await service.mission(for: "2026-05-07")

        XCTAssertEqual(provider.localDateStringForNow(), "2026-05-06")
        XCTAssertEqual(mission.localDateString, "2026-05-07")
        XCTAssertEqual(mission.createdAtUTC, now)
    }

    func testCompleteMissionIsIdempotentAndUsesInjectedClock() async throws {
        let now = instant("2026-05-07T00:30:00Z")
        let provider = makeDateProvider(instant: now, timeZone: seoulTimeZone)
        let service = makeMissionService(dateProvider: provider)

        try await seed()

        let completed = try await service.completeMission(for: "2026-05-07")
        let completedAgain = try await service.completeMission(for: "2026-05-07")
        let storedMissions = try await missionRepository.fetchAllMissions()

        XCTAssertEqual(completed.localDateString, "2026-05-07")
        XCTAssertEqual(completed.completedAtUTC, now)
        XCTAssertEqual(completedAgain.completedAtUTC, now)
        XCTAssertEqual(storedMissions.count, 1)
        XCTAssertEqual(storedMissions.first?.localDateString, "2026-05-07")
    }

    func testMissionRepositoryReturnsHistorySortedByLocalDateString() async throws {
        try await seed(missionHistory: [
            mission("2026-05-07"),
            mission("2026-05-05"),
            mission("2026-05-06")
        ])

        let missions = try await missionRepository.fetchAllMissions()

        XCTAssertEqual(missions.map(\.localDateString), [
            "2026-05-05",
            "2026-05-06",
            "2026-05-07"
        ])
    }
}
