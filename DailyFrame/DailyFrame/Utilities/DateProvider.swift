import Foundation

struct DateProvider {
    let now: () -> Date
    let calendar: Calendar

    var timeZone: TimeZone {
        calendar.timeZone
    }

    var timezoneIdentifier: String {
        timeZone.identifier
    }

    init(
        now: @escaping () -> Date = { .now },
        timeZone: TimeZone = .current
    ) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        self.init(now: now, calendar: calendar)
    }

    init(
        now: @escaping () -> Date = { .now },
        calendar: Calendar
    ) {
        var calendar = calendar
        calendar.locale = Locale(identifier: "en_US_POSIX")
        self.now = now
        self.calendar = calendar
    }

    func currentDate() -> Date {
        now()
    }

    func localDateString(from date: Date) -> String {
        DailyFrameDateFormatter.localDateString(from: date, timeZone: timeZone)
    }

    func localDateStringForNow() -> String {
        localDateString(from: currentDate())
    }

    func monthString(from date: Date) -> String {
        DailyFrameDateFormatter.monthString(from: date, timeZone: timeZone)
    }

    func date(from localDateString: String) -> Date? {
        DailyFrameDateFormatter.date(from: localDateString, timeZone: timeZone)
    }

    func localDateString(byAddingDays days: Int, to localDateString: String) -> String? {
        guard let date = date(from: localDateString),
              let adjustedDate = calendar.date(byAdding: .day, value: days, to: date) else {
            return nil
        }

        return self.localDateString(from: adjustedDate)
    }

    func dayDistance(from startLocalDateString: String, to endLocalDateString: String) -> Int? {
        guard let startDate = date(from: startLocalDateString),
              let endDate = date(from: endLocalDateString) else {
            return nil
        }

        return calendar.dateComponents([.day], from: startDate, to: endDate).day
    }

    func isAfter(_ localDateString: String, _ otherLocalDateString: String) -> Bool {
        guard let distance = dayDistance(from: otherLocalDateString, to: localDateString) else {
            return localDateString > otherLocalDateString
        }

        return distance > 0
    }
}
