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
    private let streakStateRepository: StreakStateRepository
    private let missionService: MissionService

    init(
        entryRepository: EntryRepository = EntryRepository(),
        streakStateRepository: StreakStateRepository = StreakStateRepository(),
        missionService: MissionService = MissionService()
    ) {
        self.entryRepository = entryRepository
        self.streakStateRepository = streakStateRepository
        self.missionService = missionService
    }

    var monthProgressText: String {
        "이번 달 \(currentMonthDayCount)일 중 \(monthEntryCount)일 기록"
    }

    var missionTitle: String {
        todayMission?.title ?? "오늘의 미션"
    }

    var missionPrompt: String {
        todayMission?.prompt ?? "오늘을 대표하는 장면을 한 장 남겨보세요."
    }

    var missionCategoryText: String {
        todayMission?.category ?? "기록"
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
