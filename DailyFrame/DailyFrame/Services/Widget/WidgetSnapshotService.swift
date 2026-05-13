import Foundation
import WidgetKit

struct WidgetSnapshotService {
    private let entryRepository: EntryRepository
    private let streakService: StreakService
    private let fileManager: FileManager
    private let containerURLProvider: () -> URL?
    private let timelineReloader: () -> Void

    init(
        entryRepository: EntryRepository = EntryRepository(),
        streakService: StreakService = StreakService(),
        fileManager: FileManager = .default,
        containerURLProvider: @escaping () -> URL? = {
            DailyFrameWidgetSnapshot.sharedContainerURL()
        },
        timelineReloader: @escaping () -> Void = {
            WidgetCenter.shared.reloadTimelines(ofKind: DailyFrameWidgetSnapshot.widgetKind)
        }
    ) {
        self.entryRepository = entryRepository
        self.streakService = streakService
        self.fileManager = fileManager
        self.containerURLProvider = containerURLProvider
        self.timelineReloader = timelineReloader
    }

    func refreshSnapshot(now: Date = .now) async throws {
        let snapshot = try await makeSnapshot(now: now)
        try save(snapshot)
        timelineReloader()
    }

    func makeSnapshot(now: Date = .now) async throws -> DailyFrameWidgetSnapshot {
        let todayString = DailyFrameDateFormatter.localDateString(from: now)
        let state = try await streakService.evaluateMissedYesterdayIfNeeded(now: now)
        let todayEntry = try await entryRepository.fetchEntry(for: todayString)

        return DailyFrameWidgetSnapshot(
            generatedAtUTC: now,
            localDateString: todayString,
            hasTodayEntry: todayEntry != nil,
            currentStreak: state.currentStreak,
            longestStreak: state.longestStreak,
            freezeCount: state.freezeCount,
            lastCompletedLocalDateString: state.lastCompletedLocalDateString
        )
    }

    private func save(_ snapshot: DailyFrameWidgetSnapshot) throws {
        guard let containerURL = containerURLProvider() else {
            throw CocoaError(.fileNoSuchFile)
        }

        if fileManager.fileExists(atPath: containerURL.path) == false {
            try fileManager.createDirectory(at: containerURL, withIntermediateDirectories: true)
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(snapshot)
        try data.write(to: containerURL.appending(path: DailyFrameWidgetSnapshot.fileName), options: [.atomic])
    }
}
