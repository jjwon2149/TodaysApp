import Foundation

enum DailyFrameDateFormatter {
    static func localDateString(from date: Date) -> String {
        fixedFormatter("yyyy-MM-dd").string(from: date)
    }

    static func monthString(from date: Date) -> String {
        fixedFormatter("yyyy-MM").string(from: date)
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

    static func date(from localDateString: String) -> Date? {
        fixedFormatter("yyyy-MM-dd").date(from: localDateString)
    }

    private static func fixedFormatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
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
