import Foundation

@MainActor
final class CalendarViewModel: ObservableObject {
    struct DayCell: Identifiable {
        let id: String
        let dayNumber: Int?
        let localDateString: String?
        let entry: DailyPhotoEntry?
        let isToday: Bool

        var hasEntry: Bool {
            entry != nil
        }
    }

    @Published private(set) var visibleMonth: Date
    @Published private(set) var dayCells: [DayCell] = []
    @Published private(set) var entryCount = 0
    @Published private(set) var dayCount = 0
    @Published private(set) var errorMessage: String?

    private let entryRepository: EntryRepository
    private var calendar: Calendar

    init(entryRepository: EntryRepository = EntryRepository()) {
        self.entryRepository = entryRepository

        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "ko_KR")
        calendar.timeZone = .current
        calendar.firstWeekday = 1
        self.calendar = calendar
        self.visibleMonth = calendar.startOfMonth(for: .now)
    }

    var monthTitle: String {
        DailyFrameDateFormatter.monthDisplayString(from: visibleMonth)
    }

    var monthSummary: String {
        L10n.format("calendar.month.summary", monthTitle, dayCount, entryCount)
    }

    func loadMonth() async {
        do {
            let monthPrefix = DailyFrameDateFormatter.monthString(from: visibleMonth)
            let entries = try await entryRepository.fetchEntries(inMonthPrefix: monthPrefix)
            rebuildDayCells(entries: entries)
            errorMessage = nil
        } catch {
            entryCount = 0
            rebuildDayCells(entries: [])
            errorMessage = L10n.string("error.calendar.load")
        }
    }

    func moveMonth(by value: Int) async {
        guard let nextMonth = calendar.date(byAdding: .month, value: value, to: visibleMonth) else {
            return
        }

        visibleMonth = calendar.startOfMonth(for: nextMonth)
        await loadMonth()
    }

    private func rebuildDayCells(entries: [DailyPhotoEntry]) {
        let entriesByDate = Dictionary(entries.map { ($0.localDateString, $0) }) { current, _ in current }
        let range = calendar.range(of: .day, in: .month, for: visibleMonth) ?? 1..<1
        let firstWeekday = calendar.component(.weekday, from: visibleMonth)
        let leadingEmptyCellCount = max(firstWeekday - calendar.firstWeekday, 0)
        let todayString = DailyFrameDateFormatter.localDateString(from: .now)

        entryCount = entries.count
        dayCount = range.count

        var cells = (0..<leadingEmptyCellCount).map { index in
            DayCell(
                id: "empty-\(index)",
                dayNumber: nil,
                localDateString: nil,
                entry: nil,
                isToday: false
            )
        }

        for day in range {
            guard let date = calendar.date(byAdding: .day, value: day - 1, to: visibleMonth) else {
                continue
            }

            let localDateString = DailyFrameDateFormatter.localDateString(from: date)
            cells.append(
                DayCell(
                    id: localDateString,
                    dayNumber: day,
                    localDateString: localDateString,
                    entry: entriesByDate[localDateString],
                    isToday: localDateString == todayString
                )
            )
        }

        dayCells = cells
    }
}

private extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components) ?? date
    }
}
