import Foundation

struct StreakService {
    private let repository: StreakStateRepository
    private let entryRepository: EntryRepository
    private let appSettingsRepository: AppSettingsRepository
    private let dateProvider: DateProvider

    init(
        repository: StreakStateRepository = StreakStateRepository(),
        entryRepository: EntryRepository = EntryRepository(),
        appSettingsRepository: AppSettingsRepository = AppSettingsRepository(),
        dateProvider: DateProvider = DateProvider()
    ) {
        self.repository = repository
        self.entryRepository = entryRepository
        self.appSettingsRepository = appSettingsRepository
        self.dateProvider = dateProvider
    }

    func recordCompletion(for localDateString: String) async throws {
        var state = try await repository.fetchPrimaryState()

        if let lastCompleted = state.lastCompletedLocalDateString,
           dateProvider.isAfter(localDateString, lastCompleted) == false {
            return
        }

        if let lastCompleted = state.lastCompletedLocalDateString,
           let lastDate = DailyFrameDateFormatter.date(from: lastCompleted),
           let currentDate = DailyFrameDateFormatter.date(from: localDateString),
           currentDate < lastDate {
            return
        }

        let nextStreak: Int

        if let lastCompleted = state.lastCompletedLocalDateString,
           dateProvider.dayDistance(from: lastCompleted, to: localDateString) == 1 {
            nextStreak = state.currentStreak + 1
        } else {
            nextStreak = 1
        }

        state.currentStreak = nextStreak
        state.longestStreak = max(state.longestStreak, nextStreak)
        state.lastCompletedLocalDateString = localDateString
        markEvaluated(&state, now: dateProvider.currentDate())

        try await repository.save(state)
    }

    func evaluateMissedYesterdayIfNeeded(now: Date? = nil) async throws -> StreakState {
        let now = now ?? dateProvider.currentDate()
        var state = try await repository.fetchPrimaryState()
        let todayString = dateProvider.localDateString(from: now)

        if wasAlreadyEvaluatedToday(state: state, todayString: todayString) {
            return state
        }

        state = try await evaluatedMissedYesterdayState(
            from: state,
            now: now,
            freezeUsageSource: "missed_yesterday_evaluation"
        )
        try await repository.save(state)
        return state
    }

    @discardableResult
    func rebuildFromActiveEntries(now: Date? = nil) async throws -> StreakState {
        let now = now ?? dateProvider.currentDate()
        let entries = try await entryRepository.fetchAllActiveEntries()
        let orderedDateStrings = entries.map(\.localDateString).sorted()
        let activeDateStrings = Set(orderedDateStrings)
        var state = try await repository.fetchPrimaryState()
        migrateLegacyFreezeMarkerIfNeeded(in: &state, now: now)

        if let freezeDateString = state.lastAutoAppliedFreezeLocalDateString,
           activeDateStrings.contains(freezeDateString) {
            state.lastAutoAppliedFreezeLocalDateString = nil
        }

        guard orderedDateStrings.isEmpty == false else {
            state.currentStreak = 0
            state.longestStreak = 0
            state.lastCompletedLocalDateString = nil
            state.lastAutoAppliedFreezeLocalDateString = nil
            state = try await evaluatedMissedYesterdayState(
                from: state,
                now: now,
                freezeUsageSource: "rebuild"
            )
            try await repository.save(state)
            return state
        }

        let protectedDateStrings = protectedFreezeDateStrings(
            in: state,
            excluding: activeDateStrings
        )
        let orderedTimelineDateStrings = Array(activeDateStrings.union(protectedDateStrings)).sorted()

        var previousDateString: String?
        var currentRun = 0
        var longestRun = 0
        var lastCompletedDateString: String?

        for dateString in orderedTimelineDateStrings {
            guard dateProvider.date(from: dateString) != nil else {
                continue
            }

            if let previousDateString,
               dateProvider.dayDistance(from: previousDateString, to: dateString) != 1 {
                currentRun = 0
            }

            if activeDateStrings.contains(dateString) {
                currentRun += 1
                longestRun = max(longestRun, currentRun)
            }

            previousDateString = dateString
            lastCompletedDateString = dateString
        }

        state.currentStreak = currentRun
        state.longestStreak = longestRun
        state.lastCompletedLocalDateString = lastCompletedDateString
        state = try await evaluatedMissedYesterdayState(
            from: state,
            now: now,
            freezeUsageSource: "rebuild"
        )

        try await repository.save(state)
        return state
    }

    private func evaluatedMissedYesterdayState(
        from initialState: StreakState,
        now: Date,
        freezeUsageSource: String
    ) async throws -> StreakState {
        var state = initialState
        migrateLegacyFreezeMarkerIfNeeded(in: &state, now: now)
        let todayString = dateProvider.localDateString(from: now)

        guard let yesterdayString = dateProvider.localDateString(byAddingDays: -1, to: todayString) else {
            markEvaluated(&state, now: now)
            return state
        }

        if state.lastCompletedLocalDateString == todayString || state.lastCompletedLocalDateString == yesterdayString {
            markEvaluated(&state, now: now)
            return state
        }

        let todayEntry = try await entryRepository.fetchEntry(for: todayString)
        let yesterdayEntry = try await entryRepository.fetchEntry(for: yesterdayString)

        guard todayEntry == nil, yesterdayEntry == nil else {
            markEvaluated(&state, now: now)
            return state
        }

        guard let lastCompletedString = state.lastCompletedLocalDateString,
              let daysSinceLastCompletion = dateProvider.dayDistance(from: lastCompletedString, to: todayString),
              daysSinceLastCompletion > 1 else {
            markEvaluated(&state, now: now)
            return state
        }

        let settings = try await appSettingsRepository.fetchSettings()
        let alreadyAppliedFreezeForYesterday = hasFreezeUsage(in: state, for: yesterdayString)

        if alreadyAppliedFreezeForYesterday,
           daysSinceLastCompletion == 2 {
            state.lastCompletedLocalDateString = yesterdayString
        } else if settings.autoApplyFreeze,
           state.freezeCount > 0,
           daysSinceLastCompletion == 2 {
            state.freezeCount -= 1
            state.lastCompletedLocalDateString = yesterdayString
            state.lastAutoAppliedFreezeLocalDateString = yesterdayString
            appendFreezeUsage(
                for: yesterdayString,
                to: &state,
                source: freezeUsageSource,
                now: now
            )
        } else {
            state.currentStreak = 0
            if alreadyAppliedFreezeForYesterday {
                state.lastAutoAppliedFreezeLocalDateString = nil
            }
        }

        markEvaluated(&state, now: now)
        return state
    }

    private func wasAlreadyEvaluatedToday(state: StreakState, todayString: String) -> Bool {
        guard state.lastKnownTimezoneIdentifier == dateProvider.timezoneIdentifier else {
            return false
        }

        guard let lastEvaluatedAtUTC = state.lastEvaluatedAtUTC else {
            return false
        }

        return dateProvider.localDateString(from: lastEvaluatedAtUTC) == todayString
    }

    private func markEvaluated(_ state: inout StreakState, now: Date) {
        state.lastEvaluatedAtUTC = now
        state.lastKnownTimezoneIdentifier = dateProvider.timezoneIdentifier
    }

    private func migrateLegacyFreezeMarkerIfNeeded(in state: inout StreakState, now: Date) {
        guard let freezeDateString = state.lastAutoAppliedFreezeLocalDateString,
              state.freezeUsageHistory.contains(where: {
                $0.protectedLocalDateString == freezeDateString
              }) == false else {
            return
        }

        appendFreezeUsage(
            for: freezeDateString,
            to: &state,
            source: "legacy_marker_migration",
            now: now
        )
    }

    private func protectedFreezeDateStrings(
        in state: StreakState,
        excluding activeDateStrings: Set<String>
    ) -> Set<String> {
        var protectedDateStrings = Set(
            state.freezeUsageHistory.map(\.protectedLocalDateString)
        )

        if let freezeDateString = state.lastAutoAppliedFreezeLocalDateString {
            protectedDateStrings.insert(freezeDateString)
        }

        return protectedDateStrings.subtracting(activeDateStrings)
    }

    private func hasFreezeUsage(in state: StreakState, for protectedLocalDateString: String) -> Bool {
        state.lastAutoAppliedFreezeLocalDateString == protectedLocalDateString
            || state.freezeUsageHistory.contains {
                $0.protectedLocalDateString == protectedLocalDateString
            }
    }

    private func appendFreezeUsage(
        for protectedLocalDateString: String,
        to state: inout StreakState,
        source: String,
        now: Date
    ) {
        guard state.freezeUsageHistory.contains(where: {
            $0.protectedLocalDateString == protectedLocalDateString
        }) == false else {
            return
        }

        state.freezeUsageHistory.append(
            StreakFreezeUsage(
                protectedLocalDateString: protectedLocalDateString,
                source: source,
                usedAtUTC: now,
                timezoneIdentifier: dateProvider.timezoneIdentifier
            )
        )
    }
}
