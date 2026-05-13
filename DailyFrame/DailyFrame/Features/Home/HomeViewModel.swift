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
    @Published private(set) var latestFreezeUsage: StreakFreezeUsage?

    private let entryRepository: EntryRepository
    private let streakService: StreakService
    private let missionService: MissionService
    private let dateProvider: DateProvider

    init(
        entryRepository: EntryRepository = EntryRepository(),
        streakService: StreakService = StreakService(),
        missionService: MissionService = MissionService(),
        dateProvider: DateProvider = DateProvider()
    ) {
        self.entryRepository = entryRepository
        self.streakService = streakService
        self.missionService = missionService
        self.dateProvider = dateProvider
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

    var freezeNoticeText: String? {
        guard let latestFreezeUsage else {
            return nil
        }

        let dateString = DailyFrameDateFormatter.localDateDisplayString(
            from: latestFreezeUsage.protectedLocalDateString
        )
        return L10n.format("home.freeze.notice", dateString)
    }

    var missionTitle: String {
        todayMission?.localizedTitle ?? L10n.string("home.mission.default_title")
    }

    var missionPrompt: String {
        todayMission?.localizedPrompt ?? L10n.string("home.mission.default_prompt")
    }

    var missionCategoryText: String {
        todayMission?.localizedCategory ?? L10n.string("mission.category.record")
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
            todayEntry = try await entryRepository.fetchEntry(for: dateProvider.localDateStringForNow())
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
            let state = try await streakService.evaluateMissedYesterdayIfNeeded(now: dateProvider.currentDate())
            currentStreak = state.currentStreak
            longestStreak = state.longestStreak
            freezeCount = state.freezeCount
            latestFreezeUsage = state.latestFreezeUsage
        } catch {
            currentStreak = 0
            longestStreak = 0
            freezeCount = 1
            latestFreezeUsage = nil
        }
    }

    private func loadTodayMission() async {
        do {
            todayMission = try await missionService.mission(for: dateProvider.localDateStringForNow())
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
        let now = dateProvider.currentDate()
        let monthPrefix = dateProvider.monthString(from: now)

        do {
            let monthEntries = try await entryRepository.fetchEntries(inMonthPrefix: monthPrefix)
            monthEntryCount = monthEntries.count
        } catch {
            monthEntryCount = 0
        }

        currentMonthDayCount = dateProvider.calendar.range(of: .day, in: .month, for: now)?.count ?? 30
    }
}
