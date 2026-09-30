import Foundation
import SwiftUI

enum HomeLoadState: Equatable {
    case idle
    case loading
    case loaded
    case partialFailure
    case failed
}

enum HomeSectionLoadState: Equatable {
    case idle
    case loading
    case loaded
    case failed
}

@MainActor
final class HomeViewModel: ObservableObject {
    @Published private(set) var loadState: HomeLoadState = .idle
    @Published private(set) var todayEntryLoadState: HomeSectionLoadState = .idle
    @Published private(set) var recentEntriesLoadState: HomeSectionLoadState = .idle
    @Published private(set) var streakLoadState: HomeSectionLoadState = .idle
    @Published private(set) var monthStatsLoadState: HomeSectionLoadState = .idle
    @Published private(set) var missionLoadState: HomeSectionLoadState = .idle
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
    private var activeLoadID: UUID?
    private var loadedTodayDateString: String?
    private var loadedMonthString: String?
    private var loadedMissionDateString: String?

    private(set) var hasLoadedRecentEntries = false
    private(set) var hasLoadedStreak = false

    var hasLoadedTodayEntry: Bool {
        loadedTodayDateString == dateProvider.localDateStringForNow()
    }

    var hasLoadedMonthStats: Bool {
        loadedMonthString == dateProvider.monthString(from: dateProvider.currentDate())
    }

    var hasLoadedMission: Bool {
        loadedMissionDateString == dateProvider.localDateStringForNow()
    }

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
        let currentTodayEntry = hasLoadedTodayEntry ? todayEntry : nil
        let currentTodayMission = hasLoadedMission ? todayMission : nil
        return currentTodayMission?.isCompleted == true
            || currentTodayEntry?.missionCompleted == true
            || currentTodayEntry != nil
    }

    var canPresentEntryEditor: Bool {
        todayEntryLoadState == .loaded
    }

    var hasAnyLoadedData: Bool {
        hasLoadedTodayEntry
            || hasLoadedRecentEntries
            || hasLoadedStreak
            || hasLoadedMonthStats
            || hasLoadedMission
    }

    var shouldShowLoadingPlaceholder: Bool {
        loadState == .loading && hasAnyLoadedData == false
    }

    var shouldShowFullLoadError: Bool {
        loadState == .failed && hasAnyLoadedData == false
    }

    var shouldShowPartialLoadError: Bool {
        loadState == .partialFailure || (loadState == .failed && hasAnyLoadedData)
    }

    func load() async {
        let loadID = UUID()
        let now = dateProvider.currentDate()
        let todayDateString = dateProvider.localDateString(from: now)
        activeLoadID = loadID
        loadState = .loading
        todayEntryLoadState = .loading
        recentEntriesLoadState = .loading
        streakLoadState = .loading
        monthStatsLoadState = .loading
        missionLoadState = .loading

        async let today = loadTodayEntry(for: todayDateString, loadID: loadID)
        async let recent = loadRecentEntries(loadID: loadID)
        async let streak = loadStreak(now: now, loadID: loadID)
        async let monthStats = loadMonthStats(now: now, loadID: loadID)
        async let mission = loadTodayMission(for: todayDateString, loadID: loadID)

        let results = await [today, recent, streak, monthStats, mission]
        guard activeLoadID == loadID else { return }

        await syncTodayMissionCompletionIfNeeded(loadID: loadID)
        guard activeLoadID == loadID else { return }

        let successCount = results.filter { $0 }.count
        if successCount == results.count {
            loadState = .loaded
        } else if successCount == 0 {
            loadState = .failed
        } else {
            loadState = .partialFailure
        }
    }

    private func loadTodayEntry(for localDateString: String, loadID: UUID) async -> Bool {
        do {
            let entry = try await entryRepository.fetchEntry(for: localDateString)
            guard activeLoadID == loadID else { return false }

            todayEntry = entry
            loadedTodayDateString = localDateString
            todayEntryLoadState = .loaded
            return true
        } catch {
            guard activeLoadID == loadID else { return false }
            todayEntryLoadState = .failed
            return false
        }
    }

    private func loadRecentEntries(loadID: UUID) async -> Bool {
        do {
            let entries = try await entryRepository.fetchAllActiveEntries()
            guard activeLoadID == loadID else { return false }

            recentEntries = Array(entries.sorted { $0.localDateString > $1.localDateString }.prefix(3))
            hasLoadedRecentEntries = true
            recentEntriesLoadState = .loaded
            return true
        } catch {
            guard activeLoadID == loadID else { return false }
            recentEntriesLoadState = .failed
            return false
        }
    }

    private func loadStreak(now: Date, loadID: UUID) async -> Bool {
        do {
            let state = try await streakService.evaluateMissedYesterdayIfNeeded(now: now)
            guard activeLoadID == loadID else { return false }

            currentStreak = state.currentStreak
            longestStreak = state.longestStreak
            freezeCount = state.freezeCount
            latestFreezeUsage = state.latestFreezeUsage
            hasLoadedStreak = true
            streakLoadState = .loaded
            return true
        } catch {
            guard activeLoadID == loadID else { return false }
            streakLoadState = .failed
            return false
        }
    }

    private func loadTodayMission(for localDateString: String, loadID: UUID) async -> Bool {
        do {
            let mission = try await missionService.mission(for: localDateString)
            guard activeLoadID == loadID else { return false }

            todayMission = mission
            loadedMissionDateString = localDateString
            missionLoadState = .loaded
            return true
        } catch {
            guard activeLoadID == loadID else { return false }
            missionLoadState = .failed
            return false
        }
    }

    private func syncTodayMissionCompletionIfNeeded(loadID: UUID) async {
        guard todayEntryLoadState == .loaded,
              missionLoadState == .loaded,
              todayEntry != nil,
              let todayMission,
              todayMission.isCompleted == false else {
            return
        }

        do {
            let completedMission = try await missionService.completeMission(for: todayMission.localDateString)
            guard activeLoadID == loadID else { return }
            self.todayMission = completedMission
        } catch {
            guard activeLoadID == loadID else { return }
            self.todayMission = todayMission
        }
    }

    private func loadMonthStats(now: Date, loadID: UUID) async -> Bool {
        let monthPrefix = dateProvider.monthString(from: now)

        do {
            let monthEntries = try await entryRepository.fetchEntries(inMonthPrefix: monthPrefix)
            guard activeLoadID == loadID else { return false }

            monthEntryCount = monthEntries.count
            currentMonthDayCount = dateProvider.calendar.range(of: .day, in: .month, for: now)?.count ?? 30
            loadedMonthString = monthPrefix
            monthStatsLoadState = .loaded
            return true
        } catch {
            guard activeLoadID == loadID else { return false }
            monthStatsLoadState = .failed
            return false
        }
    }
}
