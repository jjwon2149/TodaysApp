import Foundation

enum DailyFrameDateFormatter {
    static func localDateString(from date: Date) -> String {
        formatter("yyyy-MM-dd").string(from: date)
    }

    static func monthString(from date: Date) -> String {
        formatter("yyyy-MM").string(from: date)
    }

    static func monthDisplayString(from date: Date) -> String {
        formatter("yyyy년 M월").string(from: date)
    }

    static func localDateDisplayString(from localDateString: String) -> String {
        guard let date = date(from: localDateString) else {
            return localDateString
        }

        return formatter("yyyy년 M월 d일 EEEE").string(from: date)
    }

    static func date(from localDateString: String) -> Date? {
        formatter("yyyy-MM-dd").date(from: localDateString)
    }

    private static func formatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = .current
        formatter.dateFormat = format
        return formatter
    }
}
