import Foundation
import SwiftUI
import UserNotifications

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published private(set) var totalEntryCount = 0
    @Published private(set) var currentStreak = 0
    @Published private(set) var longestStreak = 0
    @Published private(set) var profileStatsStatusMessage: String?
    @Published private(set) var reminderEnabled = false
    @Published private(set) var reminderTime: Date
    @Published private(set) var notificationStatusMessage = "알림 상태를 확인하는 중입니다."
    @Published private(set) var errorMessage: String?
    @Published private(set) var isUpdatingReminder = false

    private let entryRepository: EntryRepository
    private let streakStateRepository: StreakStateRepository
    private let appSettingsRepository: AppSettingsRepository
    private let notificationService: NotificationService
    private var appSettings = AppSettings()
    private var calendar: Calendar

    init(
        entryRepository: EntryRepository = EntryRepository(),
        streakStateRepository: StreakStateRepository = StreakStateRepository(),
        appSettingsRepository: AppSettingsRepository = AppSettingsRepository(),
        notificationService: NotificationService = NotificationService(),
        calendar: Calendar = .current
    ) {
        self.entryRepository = entryRepository
        self.streakStateRepository = streakStateRepository
        self.appSettingsRepository = appSettingsRepository
        self.notificationService = notificationService
        self.calendar = calendar
        self.reminderTime = Self.date(hour: 21, minute: 0, calendar: calendar)
    }

    var totalEntriesText: String {
        "지금까지 \(totalEntryCount)일을 남겼습니다"
    }

    var currentStreakText: String {
        "\(currentStreak)일"
    }

    var longestStreakText: String {
        "\(longestStreak)일"
    }

    func load() async {
        await loadProfileStats()

        do {
            appSettings = try await appSettingsRepository.fetchSettings()
            syncPublishedState(from: appSettings)
            await refreshNotificationStatusMessage()
        } catch {
            notificationStatusMessage = "알림 설정을 불러오지 못했습니다."
        }
    }

    private func loadProfileStats() async {
        var didFail = false

        do {
            let entries = try await entryRepository.fetchAllActiveEntries()
            totalEntryCount = entries.count
        } catch {
            totalEntryCount = 0
            didFail = true
        }

        do {
            let state = try await streakStateRepository.fetchPrimaryState()
            currentStreak = max(state.currentStreak, 0)
            longestStreak = max(state.longestStreak, 0)
        } catch {
            currentStreak = 0
            longestStreak = 0
            didFail = true
        }

        profileStatsStatusMessage = didFail ? "기록 통계를 불러오지 못했습니다." : nil
    }

    func setReminderEnabled(_ isEnabled: Bool) async {
        guard isUpdatingReminder == false else { return }

        isUpdatingReminder = true
        errorMessage = nil
        defer { isUpdatingReminder = false }

        if isEnabled {
            await enableReminder()
        } else {
            await disableReminder()
        }

        await refreshNotificationStatusMessage()
    }

    func setReminderTime(_ date: Date) async {
        guard isUpdatingReminder == false else { return }

        isUpdatingReminder = true
        errorMessage = nil
        defer { isUpdatingReminder = false }

        let components = reminderComponents(from: date)
        reminderTime = Self.date(hour: components.hour, minute: components.minute, calendar: calendar)

        do {
            if reminderEnabled {
                let status = await notificationService.authorizationStatus()

                guard Self.canScheduleNotification(for: status) else {
                    notificationService.cancelDailyReminder()
                    try await persistNotificationSettings(
                        reminderEnabled: false,
                        hour: components.hour,
                        minute: components.minute,
                        permissionPrompted: appSettings.notificationsPermissionPrompted
                    )
                    errorMessage = permissionDeniedMessage
                    await refreshNotificationStatusMessage()
                    return
                }

                try await notificationService.scheduleDailyReminder(
                    hour: components.hour,
                    minute: components.minute
                )
            }

            try await persistNotificationSettings(
                reminderEnabled: reminderEnabled,
                hour: components.hour,
                minute: components.minute,
                permissionPrompted: appSettings.notificationsPermissionPrompted
            )
        } catch {
            errorMessage = "알림 시간을 저장하지 못했습니다."
            syncPublishedState(from: appSettings)
        }

        await refreshNotificationStatusMessage()
    }

    private func enableReminder() async {
        let components = reminderComponents(from: reminderTime)

        do {
            let status = try await notificationService.requestAuthorizationIfNeeded()

            guard Self.canScheduleNotification(for: status) else {
                notificationService.cancelDailyReminder()
                try await persistNotificationSettings(
                    reminderEnabled: false,
                    hour: components.hour,
                    minute: components.minute,
                    permissionPrompted: true
                )
                errorMessage = permissionDeniedMessage
                return
            }

            try await notificationService.scheduleDailyReminder(
                hour: components.hour,
                minute: components.minute
            )
            try await persistNotificationSettings(
                reminderEnabled: true,
                hour: components.hour,
                minute: components.minute,
                permissionPrompted: true
            )
        } catch {
            notificationService.cancelDailyReminder()
            try? await persistNotificationSettings(
                reminderEnabled: false,
                hour: components.hour,
                minute: components.minute,
                permissionPrompted: true
            )
            errorMessage = "알림을 켜지 못했습니다."
        }
    }

    private func disableReminder() async {
        let components = reminderComponents(from: reminderTime)
        notificationService.cancelDailyReminder()

        do {
            try await persistNotificationSettings(
                reminderEnabled: false,
                hour: components.hour,
                minute: components.minute,
                permissionPrompted: appSettings.notificationsPermissionPrompted
            )
        } catch {
            errorMessage = "알림 설정을 저장하지 못했습니다."
            syncPublishedState(from: appSettings)
        }
    }

    private func persistNotificationSettings(
        reminderEnabled: Bool,
        hour: Int,
        minute: Int,
        permissionPrompted: Bool
    ) async throws {
        appSettings = try await appSettingsRepository.updateNotificationSettings(
            reminderEnabled: reminderEnabled,
            reminderHour: hour,
            reminderMinute: minute,
            notificationsPermissionPrompted: permissionPrompted
        )
        syncPublishedState(from: appSettings)
    }

    private func refreshNotificationStatusMessage() async {
        let status = await notificationService.authorizationStatus()

        switch status {
        case .authorized, .provisional, .ephemeral:
            notificationStatusMessage = reminderEnabled
                ? "매일 \(formattedReminderTime)에 알려드립니다."
                : "알림 권한이 허용되어 있습니다."
        case .denied:
            notificationStatusMessage = "iOS 설정에서 DailyFrame 알림이 꺼져 있습니다."
        case .notDetermined:
            notificationStatusMessage = "알림을 켜면 권한 요청이 표시됩니다."
        @unknown default:
            notificationStatusMessage = "현재 알림 상태를 확인할 수 없습니다."
        }
    }

    private func syncPublishedState(from settings: AppSettings) {
        reminderEnabled = settings.reminderEnabled
        reminderTime = Self.date(
            hour: settings.reminderHour ?? 21,
            minute: settings.reminderMinute ?? 0,
            calendar: calendar
        )
    }

    private var formattedReminderTime: String {
        let components = reminderComponents(from: reminderTime)
        return String(format: "%02d:%02d", components.hour, components.minute)
    }

    private var permissionDeniedMessage: String {
        "알림 권한이 꺼져 있어요. iOS 설정에서 허용하면 다시 켤 수 있습니다."
    }

    private func reminderComponents(from date: Date) -> (hour: Int, minute: Int) {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return (
            hour: components.hour ?? appSettings.reminderHour ?? 21,
            minute: components.minute ?? appSettings.reminderMinute ?? 0
        )
    }

    private static func date(hour: Int, minute: Int, calendar: Calendar) -> Date {
        var components = calendar.dateComponents([.year, .month, .day], from: .now)
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components) ?? .now
    }

    private static func canScheduleNotification(for status: UNAuthorizationStatus) -> Bool {
        switch status {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied, .notDetermined:
            return false
        @unknown default:
            return false
        }
    }
}
