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
    @Published private(set) var todayMission: DailyMission?

    private let entryRepository: EntryRepository
    private let streakService: StreakService
    private let missionService: MissionService

    init(
        entryRepository: EntryRepository = EntryRepository(),
        streakService: StreakService = StreakService(),
        missionService: MissionService = MissionService()
    ) {
        self.entryRepository = entryRepository
        self.streakService = streakService
        self.missionService = missionService
    }

    var monthProgressText: String {
        L10n.format("home.progress.summary", currentMonthDayCount, monthEntryCount)
    }

    var headerSubtitle: String {
        currentStreak > 0
            ? L10n.format("home.header.streak_active", currentStreak)
            : L10n.string("home.header.streak_empty")
    }

    var currentStreakTitle: String {
        L10n.format("home.streak.title", currentStreak)
    }

    var streakSummaryText: String {
        L10n.format("home.streak.summary", longestStreak, freezeCount)
    }

    var missionTitle: String {
        todayMission?.title ?? L10n.string("home.mission.default_title")
    }

    var missionPrompt: String {
        todayMission?.prompt ?? L10n.string("home.mission.default_prompt")
    }

    var missionCategoryText: String {
        todayMission?.category ?? L10n.string("mission.category.record")
    }

    var missionSymbolName: String {
        todayMission?.symbolName ?? "sparkles"
    }

    var isTodayMissionCompleted: Bool {
        todayMission?.isCompleted == true || todayEntry?.missionCompleted == true || todayEntry != nil
    }

    func load() async {
        async let today: () = loadTodayEntry()
        async let recent: () = loadRecentEntries()
        async let streak: () = loadStreak()
        async let monthStats: () = loadMonthStats()
        async let mission: () = loadTodayMission()

        _ = await (today, recent, streak, monthStats, mission)
        await syncTodayMissionCompletionIfNeeded()
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
            let state = try await streakService.evaluateMissedYesterdayIfNeeded()
            currentStreak = state.currentStreak
            longestStreak = state.longestStreak
            freezeCount = state.freezeCount
        } catch {
            currentStreak = 0
            longestStreak = 0
            freezeCount = 1
        }
    }

    private func loadTodayMission() async {
        do {
            todayMission = try await missionService.mission(for: DailyFrameDateFormatter.localDateString(from: .now))
        } catch {
            todayMission = nil
        }
    }

    private func syncTodayMissionCompletionIfNeeded() async {
        guard todayEntry != nil,
              let todayMission,
              todayMission.isCompleted == false else {
            return
        }

        do {
            self.todayMission = try await missionService.completeMission(for: todayMission.localDateString)
        } catch {
            self.todayMission = todayMission
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
