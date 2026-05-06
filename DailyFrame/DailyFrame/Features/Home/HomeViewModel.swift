import Foundation
import SwiftUI

@MainActor
final class HomeViewModel: ObservableObject {
    @Published private(set) var todayEntry: DailyPhotoEntry?
    @Published private(set) var recentEntries: [DailyPhotoEntry] = []
    @Published private(set) var currentStreak = 0
    @Published private(set) var longestStreak = 0
    @Published private(set) var freezeCount = 1
    @Published private(set) var monthEntryCount = 0
    @Published private(set) var currentMonthDayCount = 30

    private let entryRepository: EntryRepository
    private let streakStateRepository: StreakStateRepository

    init(
        entryRepository: EntryRepository = EntryRepository(),
        streakStateRepository: StreakStateRepository = StreakStateRepository()
    ) {
        self.entryRepository = entryRepository
        self.streakStateRepository = streakStateRepository
    }

    var monthProgressText: String {
        "이번 달 \(currentMonthDayCount)일 중 \(monthEntryCount)일 기록"
    }

    func load() async {
        async let today = loadTodayEntry()
        async let recent = loadRecentEntries()
        async let streak = loadStreak()
        async let monthStats = loadMonthStats()

        _ = await (today, recent, streak, monthStats)
    }

    private func loadTodayEntry() async {
        do {
            todayEntry = try await entryRepository.fetchEntry(for: DailyFrameDateFormatter.localDateString(from: .now))
        } catch {
            todayEntry = nil
        }
    }

    private func loadRecentEntries() async {
        do {
            let entries = try await entryRepository.fetchAllActiveEntries()
            recentEntries = Array(entries.sorted { $0.localDateString > $1.localDateString }.prefix(3))
        } catch {
            recentEntries = []
        }
    }

    private func loadStreak() async {
        do {
            let state = try await streakStateRepository.fetchPrimaryState()
            currentStreak = state.currentStreak
            longestStreak = state.longestStreak
            freezeCount = state.freezeCount
        } catch {
            currentStreak = 0
            longestStreak = 0
            freezeCount = 1
        }
    }

    private func loadMonthStats() async {
        let now = Date()
        let monthPrefix = DailyFrameDateFormatter.monthString(from: now)

        do {
            let monthEntries = try await entryRepository.fetchEntries(inMonthPrefix: monthPrefix)
            monthEntryCount = monthEntries.count
        } catch {
            monthEntryCount = 0
        }

        currentMonthDayCount = Calendar.current.range(of: .day, in: .month, for: now)?.count ?? 30
    }
}
