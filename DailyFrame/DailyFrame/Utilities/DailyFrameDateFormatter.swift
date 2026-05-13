import Foundation

enum DailyFrameDateFormatter {
    static func localDateString(from date: Date, timeZone: TimeZone = .current) -> String {
        fixedFormatter("yyyy-MM-dd", timeZone: timeZone).string(from: date)
    }

    static func monthString(from date: Date, timeZone: TimeZone = .current) -> String {
        fixedFormatter("yyyy-MM", timeZone: timeZone).string(from: date)
    }

    static func monthDisplayString(from date: Date) -> String {
        displayFormatter(L10n.string("date.format.month")).string(from: date)
    }

    static func localDateDisplayString(from localDateString: String) -> String {
        guard let date = date(from: localDateString) else {
            return localDateString
        }

        return displayFormatter(L10n.string("date.format.full")).string(from: date)
    }

    static func date(from localDateString: String, timeZone: TimeZone = .current) -> Date? {
        fixedFormatter("yyyy-MM-dd", timeZone: timeZone).date(from: localDateString)
    }

    private static func fixedFormatter(_ format: String, timeZone: TimeZone) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = format
        return formatter
    }

    private static func displayFormatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = .current
        formatter.timeZone = .current
        formatter.dateFormat = format
        return formatter
    }
}
