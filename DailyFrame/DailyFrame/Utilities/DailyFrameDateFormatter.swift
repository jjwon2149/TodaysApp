import Foundation

enum DailyFrameDateFormatter {
    static func localDateString(from date: Date) -> String {
        formatter("yyyy-MM-dd").string(from: date)
    }

    static func monthString(from date: Date) -> String {
        formatter("yyyy-MM").string(from: date)
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
