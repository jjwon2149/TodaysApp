import Foundation

struct DailyFrameWidgetSnapshot: Codable, Equatable {
    static let appGroupIdentifier = "group.com.mabataki.smithwrld999.DailyFrame"
    static let fileName = "dailyframe-widget-snapshot.json"
    static let widgetKind = "DailyFrameTodayWidget"

    var generatedAtUTC: Date
    var localDateString: String
    var hasTodayEntry: Bool
    var currentStreak: Int
    var longestStreak: Int
    var freezeCount: Int
    var lastCompletedLocalDateString: String?

    static var placeholder: DailyFrameWidgetSnapshot {
        DailyFrameWidgetSnapshot(
            generatedAtUTC: .now,
            localDateString: localDateString(from: .now),
            hasTodayEntry: false,
            currentStreak: 0,
            longestStreak: 0,
            freezeCount: 0,
            lastCompletedLocalDateString: nil
        )
    }

    static func sharedContainerURL(fileManager: FileManager = .default) -> URL? {
        fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
    }

    static func snapshotFileURL(fileManager: FileManager = .default) -> URL? {
        sharedContainerURL(fileManager: fileManager)?.appending(path: fileName)
    }

    static func localDateString(from date: Date) -> String {
        fixedFormatter("yyyy-MM-dd").string(from: date)
    }

    static func date(from localDateString: String) -> Date? {
        fixedFormatter("yyyy-MM-dd").date(from: localDateString)
    }

    func hasEntry(on date: Date) -> Bool {
        hasTodayEntry && localDateString == Self.localDateString(from: date)
    }

    func displayCurrentStreak(on date: Date) -> Int {
        let todayString = Self.localDateString(from: date)

        if localDateString == todayString {
            return max(currentStreak, 0)
        }

        guard let lastCompletedLocalDateString,
              let lastCompletedDate = Self.date(from: lastCompletedLocalDateString),
              let todayDate = Self.date(from: todayString),
              let daysSinceCompletion = Calendar.current.dateComponents(
                [.day],
                from: lastCompletedDate,
                to: todayDate
              ).day else {
            return 0
        }

        return daysSinceCompletion <= 1 ? max(currentStreak, 0) : 0
    }

    static func nextMidnightRefreshDate(after date: Date) -> Date {
        Calendar.current.nextDate(
            after: date,
            matching: DateComponents(hour: 0, minute: 5),
            matchingPolicy: .nextTime
        ) ?? date.addingTimeInterval(60 * 60)
    }

    private static func fixedFormatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = format
        return formatter
    }
}

enum DailyFrameWidgetDeepLink {
    static let todayURL = URL(string: "dailyframe://today")!

    static func isTodayURL(_ url: URL) -> Bool {
        guard url.scheme == "dailyframe" else {
            return false
        }

        return url.host == "today" || url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")) == "today"
    }
}
