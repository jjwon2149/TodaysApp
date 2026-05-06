import Foundation

struct StreakService {
    private let repository: StreakStateRepository
    private let entryRepository: EntryRepository

    init(
        repository: StreakStateRepository = StreakStateRepository(),
        entryRepository: EntryRepository = EntryRepository()
    ) {
        self.repository = repository
        self.entryRepository = entryRepository
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
}
