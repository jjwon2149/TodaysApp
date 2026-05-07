import Foundation

struct StreakService {
    private let repository: StreakStateRepository
    private let entryRepository: EntryRepository
    private let appSettingsRepository: AppSettingsRepository

    init(
        repository: StreakStateRepository = StreakStateRepository(),
        entryRepository: EntryRepository = EntryRepository(),
        appSettingsRepository: AppSettingsRepository = AppSettingsRepository()
    ) {
        self.repository = repository
        self.entryRepository = entryRepository
        self.appSettingsRepository = appSettingsRepository
    }

    func recordCompletion(for localDateString: String) async throws {
        var state = try await repository.fetchPrimaryState()

        if state.lastCompletedLocalDateString == localDateString {
            return
        }

        let nextStreak: Int

        if let lastCompleted = state.lastCompletedLocalDateString,
           let lastDate = DailyFrameDateFormatter.date(from: lastCompleted),
           let currentDate = DailyFrameDateFormatter.date(from: localDateString),
           Calendar.current.dateComponents([.day], from: lastDate, to: currentDate).day == 1 {
            nextStreak = state.currentStreak + 1
        } else {
            nextStreak = 1
        }

        state.currentStreak = nextStreak
        state.longestStreak = max(state.longestStreak, nextStreak)
        state.lastCompletedLocalDateString = localDateString
        state.lastEvaluatedAtUTC = .now
        state.lastKnownTimezoneIdentifier = TimeZone.current.identifier

        try await repository.save(state)
    }

    func evaluateMissedYesterdayIfNeeded(now: Date = .now) async throws -> StreakState {
        var state = try await repository.fetchPrimaryState()
        let todayString = DailyFrameDateFormatter.localDateString(from: now)

        if wasAlreadyEvaluatedToday(state: state, todayString: todayString) {
            return state
        }

        guard let todayDate = DailyFrameDateFormatter.date(from: todayString),
              let yesterdayDate = Calendar.current.date(byAdding: .day, value: -1, to: todayDate) else {
            state.lastEvaluatedAtUTC = now
            state.lastKnownTimezoneIdentifier = TimeZone.current.identifier
            try await repository.save(state)
            return state
        }

        let yesterdayString = DailyFrameDateFormatter.localDateString(from: yesterdayDate)

        if state.lastCompletedLocalDateString == todayString || state.lastCompletedLocalDateString == yesterdayString {
            state.lastEvaluatedAtUTC = now
            state.lastKnownTimezoneIdentifier = TimeZone.current.identifier
            try await repository.save(state)
            return state
        }

        let todayEntry = try await entryRepository.fetchEntry(for: todayString)
        let yesterdayEntry = try await entryRepository.fetchEntry(for: yesterdayString)

        guard todayEntry == nil, yesterdayEntry == nil else {
            state.lastEvaluatedAtUTC = now
            state.lastKnownTimezoneIdentifier = TimeZone.current.identifier
            try await repository.save(state)
            return state
        }

        guard let lastCompletedString = state.lastCompletedLocalDateString,
              let lastCompletedDate = DailyFrameDateFormatter.date(from: lastCompletedString),
              let daysSinceLastCompletion = Calendar.current.dateComponents(
                [.day],
                from: lastCompletedDate,
                to: todayDate
              ).day,
              daysSinceLastCompletion > 1 else {
            state.lastEvaluatedAtUTC = now
            state.lastKnownTimezoneIdentifier = TimeZone.current.identifier
            try await repository.save(state)
            return state
        }

        let settings = try await appSettingsRepository.fetchSettings()

        if settings.autoApplyFreeze,
           state.freezeCount > 0,
           daysSinceLastCompletion == 2 {
            state.freezeCount -= 1
            state.lastCompletedLocalDateString = yesterdayString
        } else {
            state.currentStreak = 0
        }

        state.lastEvaluatedAtUTC = now
        state.lastKnownTimezoneIdentifier = TimeZone.current.identifier

        try await repository.save(state)
        return state
    }

    func rebuildFromActiveEntries() async throws {
        let entries = try await entryRepository.fetchAllActiveEntries()
        let orderedDateStrings = entries.map(\.localDateString).sorted()
        var state = try await repository.fetchPrimaryState()

        guard orderedDateStrings.isEmpty == false else {
            state.currentStreak = 0
            state.longestStreak = 0
            state.lastCompletedLocalDateString = nil
            state.lastEvaluatedAtUTC = .now
            state.lastKnownTimezoneIdentifier = TimeZone.current.identifier
            try await repository.save(state)
            return
        }

        var previousDate: Date?
        var currentRun = 0
        var longestRun = 0
        var lastValidDateString: String?

        for dateString in orderedDateStrings {
            guard let date = DailyFrameDateFormatter.date(from: dateString) else {
                continue
            }

            if let previousDate,
               Calendar.current.dateComponents([.day], from: previousDate, to: date).day == 1 {
                currentRun += 1
            } else {
                currentRun = 1
            }

            longestRun = max(longestRun, currentRun)
            previousDate = date
            lastValidDateString = dateString
        }

        state.currentStreak = currentRun
        state.longestStreak = longestRun
        state.lastCompletedLocalDateString = lastValidDateString
        state.lastEvaluatedAtUTC = .now
        state.lastKnownTimezoneIdentifier = TimeZone.current.identifier

        try await repository.save(state)
    }

    private func wasAlreadyEvaluatedToday(state: StreakState, todayString: String) -> Bool {
        guard let lastEvaluatedAtUTC = state.lastEvaluatedAtUTC else {
            return false
        }

        return DailyFrameDateFormatter.localDateString(from: lastEvaluatedAtUTC) == todayString
    }
}
