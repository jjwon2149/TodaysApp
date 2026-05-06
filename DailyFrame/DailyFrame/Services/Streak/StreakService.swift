import Foundation

struct StreakService {
    private let repository: StreakStateRepository

    init(repository: StreakStateRepository = StreakStateRepository()) {
        self.repository = repository
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
}
