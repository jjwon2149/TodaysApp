import Foundation
import UserNotifications

struct NotificationService {
    static let dailyReminderIdentifier = "daily-photo-reminder"

    private let notificationCenter: UNUserNotificationCenter

    init(notificationCenter: UNUserNotificationCenter = .current()) {
        self.notificationCenter = notificationCenter
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        let settings = await notificationCenter.notificationSettings()
        return settings.authorizationStatus
    }

    func requestAuthorizationIfNeeded() async throws -> UNAuthorizationStatus {
        let currentStatus = await authorizationStatus()

        guard currentStatus == .notDetermined else {
            return currentStatus
        }

        _ = try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
        return await authorizationStatus()
    }

    func scheduleDailyReminder(hour: Int, minute: Int) async throws {
        cancelDailyReminder()

        let content = UNMutableNotificationContent()
        content.title = "오늘의 한 장을 남길 시간"
        content.body = "사진 한 장으로 오늘을 조용히 저장해보세요."
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: Self.dailyReminderIdentifier,
            content: content,
            trigger: trigger
        )

        try await notificationCenter.add(request)
    }

    func cancelDailyReminder() {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [Self.dailyReminderIdentifier])
    }
}
