import XCTest
@testable import DailyFrame

final class StreakServiceTests: DomainTestFixture {
    func testRecordCompletionIsIdempotentAndIgnoresPastEntryEdits() async throws {
        let provider = makeDateProvider(now: "2026-05-07")
        let service = makeStreakService(dateProvider: provider)

        try await seed(
            streakState: StreakState(
                currentStreak: 4,
                longestStreak: 4,
                lastCompletedLocalDateString: "2026-05-07",
                freezeCount: 2
            )
        )

        try await service.recordCompletion(for: "2026-05-07")
        try await service.recordCompletion(for: "2026-05-06")

        let state = try await streakRepository.fetchPrimaryState()
        XCTAssertEqual(state.currentStreak, 4)
        XCTAssertEqual(state.longestStreak, 4)
        XCTAssertEqual(state.freezeCount, 2)
        XCTAssertEqual(state.lastCompletedLocalDateString, "2026-05-07")
    }

    func testEvaluateUsesFreezeForD2GapAndIsSameDayIdempotent() async throws {
        let provider = makeDateProvider(now: "2026-05-07")
        let service = makeStreakService(dateProvider: provider)

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

        let evaluated = try await service.evaluateMissedYesterdayIfNeeded()

        XCTAssertEqual(evaluated.currentStreak, 3)
        XCTAssertEqual(evaluated.longestStreak, 3)
        XCTAssertEqual(evaluated.freezeCount, 1)
        XCTAssertEqual(evaluated.lastCompletedLocalDateString, "2026-05-06")
        XCTAssertEqual(evaluated.lastAutoAppliedFreezeLocalDateString, "2026-05-06")
        XCTAssertEqual(evaluated.freezeUsageHistory.map(\.protectedLocalDateString), ["2026-05-06"])
        XCTAssertEqual(evaluated.freezeUsageHistory.first?.timezoneIdentifier, "Asia/Seoul")

        let evaluatedAgain = try await service.evaluateMissedYesterdayIfNeeded()

        XCTAssertEqual(evaluatedAgain.freezeCount, 1)
        XCTAssertEqual(evaluatedAgain.freezeUsageHistory.count, 1)
        XCTAssertEqual(evaluatedAgain.lastCompletedLocalDateString, "2026-05-06")
    }

    func testEvaluateDoesNotUseFreezeForD1OrTodayCompletion() async throws {
        let provider = makeDateProvider(now: "2026-05-07")
        let service = makeStreakService(dateProvider: provider)

        try await seed(
            entries: [entry("2026-05-06")],
            streakState: StreakState(
                currentStreak: 3,
                longestStreak: 3,
                lastCompletedLocalDateString: "2026-05-06",
                freezeCount: 1
            )
        )

        let d1Evaluated = try await service.evaluateMissedYesterdayIfNeeded()
        XCTAssertEqual(d1Evaluated.freezeCount, 1)
        XCTAssertTrue(d1Evaluated.freezeUsageHistory.isEmpty)

        try await seed(
            entries: [entry("2026-05-07")],
            streakState: StreakState(
                currentStreak: 4,
                longestStreak: 4,
                lastCompletedLocalDateString: "2026-05-07",
                freezeCount: 1
            )
        )

        let todayEvaluated = try await service.evaluateMissedYesterdayIfNeeded()
        XCTAssertEqual(todayEvaluated.freezeCount, 1)
        XCTAssertTrue(todayEvaluated.freezeUsageHistory.isEmpty)
    }

    func testEvaluateResetsCurrentStreakForD2GapWithoutFreeze() async throws {
        let provider = makeDateProvider(now: "2026-05-07")
        let service = makeStreakService(dateProvider: provider)

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

        let evaluated = try await service.evaluateMissedYesterdayIfNeeded()

        XCTAssertEqual(evaluated.currentStreak, 0)
        XCTAssertEqual(evaluated.longestStreak, 3)
        XCTAssertEqual(evaluated.freezeCount, 0)
        XCTAssertEqual(evaluated.lastCompletedLocalDateString, "2026-05-05")
        XCTAssertTrue(evaluated.freezeUsageHistory.isEmpty)
    }

    func testEvaluateDoesNotConsumeFreezeWhenAutoApplyIsOffOrGapIsLongerThanOneDay() async throws {
        let provider = makeDateProvider(now: "2026-05-07")
        let service = makeStreakService(dateProvider: provider)

        try await seed(
            entries: [entry("2026-05-05")],
            streakState: StreakState(
                currentStreak: 1,
                longestStreak: 3,
                lastCompletedLocalDateString: "2026-05-05",
                freezeCount: 2
            ),
            settings: AppSettings(autoApplyFreeze: false)
        )

        let autoApplyOff = try await service.evaluateMissedYesterdayIfNeeded()
        XCTAssertEqual(autoApplyOff.currentStreak, 0)
        XCTAssertEqual(autoApplyOff.freezeCount, 2)
        XCTAssertTrue(autoApplyOff.freezeUsageHistory.isEmpty)

        try await seed(
            entries: [entry("2026-05-04")],
            streakState: StreakState(
                currentStreak: 1,
                longestStreak: 3,
                lastCompletedLocalDateString: "2026-05-04",
                freezeCount: 2
            )
        )

        let longerGap = try await service.evaluateMissedYesterdayIfNeeded()
        XCTAssertEqual(longerGap.currentStreak, 0)
        XCTAssertEqual(longerGap.freezeCount, 2)
        XCTAssertTrue(longerGap.freezeUsageHistory.isEmpty)
    }

    func testTimezoneProviderSeparatesKoreaAndLosAngelesLocalDates() async throws {
        let instant = instant("2026-05-06T16:30:00Z")
        let seoulProvider = makeDateProvider(instant: instant, timeZone: seoulTimeZone)
        let losAngelesProvider = makeDateProvider(instant: instant, timeZone: losAngelesTimeZone)

        XCTAssertEqual(seoulProvider.localDateStringForNow(), "2026-05-07")
        XCTAssertEqual(losAngelesProvider.localDateStringForNow(), "2026-05-06")

        try await seed(
            entries: [entry("2026-05-05", timeZone: seoulTimeZone)],
            streakState: StreakState(
                currentStreak: 1,
                longestStreak: 1,
                lastCompletedLocalDateString: "2026-05-05",
                freezeCount: 1,
                lastEvaluatedAtUTC: instant,
                lastKnownTimezoneIdentifier: seoulTimeZone.identifier
            )
        )

        let service = makeStreakService(dateProvider: losAngelesProvider)
        let evaluated = try await service.evaluateMissedYesterdayIfNeeded()

        XCTAssertEqual(evaluated.freezeCount, 1)
        XCTAssertEqual(evaluated.lastKnownTimezoneIdentifier, losAngelesTimeZone.identifier)
    }

    func testDSTBoundaryUsesCalendarDayDistanceForFreeze() async throws {
        let provider = makeDateProvider(now: "2026-03-09", timeZone: losAngelesTimeZone)
        let service = makeStreakService(dateProvider: provider)

        try await seed(
            entries: [entry("2026-03-07", timeZone: losAngelesTimeZone)],
            streakState: StreakState(
                currentStreak: 1,
                longestStreak: 1,
                lastCompletedLocalDateString: "2026-03-07",
                freezeCount: 1
            )
        )

        let evaluated = try await service.evaluateMissedYesterdayIfNeeded()

        XCTAssertEqual(evaluated.currentStreak, 1)
        XCTAssertEqual(evaluated.freezeCount, 0)
        XCTAssertEqual(evaluated.lastCompletedLocalDateString, "2026-03-08")
        XCTAssertEqual(evaluated.freezeUsageHistory.first?.protectedLocalDateString, "2026-03-08")
    }

    func testRebuildBridgesFreezeUsageWithoutCountingFreezeAsEntry() async throws {
        let provider = makeDateProvider(now: "2026-05-07")
        let service = makeStreakService(dateProvider: provider)
        let freezeUsage = StreakFreezeUsage(
            protectedLocalDateString: "2026-05-06",
            source: "missed_yesterday_evaluation",
            usedAtUTC: localDate("2026-05-07"),
            timezoneIdentifier: seoulTimeZone.identifier
        )

        try await seed(
            entries: [
                entry("2026-05-05"),
                entry("2026-05-07")
            ],
            streakState: StreakState(
                currentStreak: 2,
                longestStreak: 2,
                lastCompletedLocalDateString: "2026-05-07",
                freezeCount: 0,
                lastAutoAppliedFreezeLocalDateString: "2026-05-06",
                freezeUsageHistory: [freezeUsage]
            )
        )

        let rebuilt = try await service.rebuildFromActiveEntries()

        XCTAssertEqual(rebuilt.currentStreak, 2)
        XCTAssertEqual(rebuilt.longestStreak, 2)
        XCTAssertEqual(rebuilt.freezeCount, 0)
        XCTAssertEqual(rebuilt.lastCompletedLocalDateString, "2026-05-07")
        XCTAssertEqual(rebuilt.freezeUsageHistory.count, 1)
    }

    func testRebuildAppliesMissedYesterdayPolicyAfterSoftDelete() async throws {
        let provider = makeDateProvider(now: "2026-05-07")
        let service = makeStreakService(dateProvider: provider)

        try await seed(
            entries: [entry("2026-05-05")],
            streakState: StreakState(
                currentStreak: 1,
                longestStreak: 1,
                lastCompletedLocalDateString: "2026-05-05",
                freezeCount: 1,
                lastEvaluatedAtUTC: localDate("2026-05-07")
            )
        )

        let rebuilt = try await service.rebuildFromActiveEntries()

        XCTAssertEqual(rebuilt.currentStreak, 1)
        XCTAssertEqual(rebuilt.longestStreak, 1)
        XCTAssertEqual(rebuilt.freezeCount, 0)
        XCTAssertEqual(rebuilt.lastCompletedLocalDateString, "2026-05-06")
        XCTAssertEqual(rebuilt.lastAutoAppliedFreezeLocalDateString, "2026-05-06")
        XCTAssertEqual(rebuilt.freezeUsageHistory.map(\.protectedLocalDateString), ["2026-05-06"])
    }

    func testRebuildDoesNotConsumeSecondFreezeWhenSameDayFreezeWasAlreadyApplied() async throws {
        let provider = makeDateProvider(now: "2026-05-07")
        let service = makeStreakService(dateProvider: provider)
        let freezeUsage = StreakFreezeUsage(
            protectedLocalDateString: "2026-05-06",
            source: "missed_yesterday_evaluation",
            usedAtUTC: localDate("2026-05-07"),
            timezoneIdentifier: seoulTimeZone.identifier
        )

        try await seed(
            entries: [entry("2026-05-05")],
            streakState: StreakState(
                currentStreak: 1,
                longestStreak: 1,
                lastCompletedLocalDateString: "2026-05-06",
                freezeCount: 1,
                lastAutoAppliedFreezeLocalDateString: "2026-05-06",
                freezeUsageHistory: [freezeUsage],
                lastEvaluatedAtUTC: localDate("2026-05-07")
            )
        )

        let rebuilt = try await service.rebuildFromActiveEntries()

        XCTAssertEqual(rebuilt.currentStreak, 1)
        XCTAssertEqual(rebuilt.longestStreak, 1)
        XCTAssertEqual(rebuilt.freezeCount, 1)
        XCTAssertEqual(rebuilt.lastCompletedLocalDateString, "2026-05-06")
        XCTAssertEqual(rebuilt.lastAutoAppliedFreezeLocalDateString, "2026-05-06")
        XCTAssertEqual(rebuilt.freezeUsageHistory.count, 1)
    }
}
