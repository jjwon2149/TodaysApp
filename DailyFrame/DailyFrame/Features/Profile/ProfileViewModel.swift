import Foundation
import SwiftUI
import UserNotifications

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published private(set) var totalEntryCount = 0
    @Published private(set) var currentStreak = 0
    @Published private(set) var longestStreak = 0
    @Published private(set) var freezeCount = 1
    @Published private(set) var latestFreezeUsage: StreakFreezeUsage?
    @Published private(set) var profileStatsStatusMessage: String?
    @Published private(set) var reminderEnabled = false
    @Published private(set) var reminderTime: Date
    @Published private(set) var notificationStatusMessage = L10n.string("profile.notification.status.loading")
    @Published private(set) var errorMessage: String?
    @Published private(set) var isUpdatingReminder = false
    @Published private(set) var isExportingArchive = false
    @Published private(set) var exportedArchiveURL: URL?
    @Published private(set) var exportStatusMessage: String?

    private let entryRepository: EntryRepository
    private let streakService: StreakService
    private let streakStateRepository: StreakStateRepository
    private let appSettingsRepository: AppSettingsRepository
    private let notificationService: NotificationService
    private let dateProvider: DateProvider
    private let exportService: ExportService
    private var appSettings = AppSettings()
    private var calendar: Calendar

    init(
        entryRepository: EntryRepository = EntryRepository(),
        streakService: StreakService = StreakService(),
        streakStateRepository: StreakStateRepository = StreakStateRepository(),
        appSettingsRepository: AppSettingsRepository = AppSettingsRepository(),
        notificationService: NotificationService = NotificationService(),
        exportService: ExportService = ExportService(),
        dateProvider: DateProvider = DateProvider()
    ) {
        self.entryRepository = entryRepository
        self.streakService = streakService
        self.streakStateRepository = streakStateRepository
        self.appSettingsRepository = appSettingsRepository
        self.notificationService = notificationService
        self.exportService = exportService
        self.dateProvider = dateProvider
        self.calendar = dateProvider.calendar
        self.reminderTime = Self.date(hour: 21, minute: 0, calendar: dateProvider.calendar, now: dateProvider.currentDate())
    }

    var totalEntriesText: String {
        L10n.format("profile.total_entries", totalEntryCount)
    }

    var currentStreakText: String {
        L10n.format("common.days_count", currentStreak)
    }

    var longestStreakText: String {
        L10n.format("common.days_count", longestStreak)
    }

    var freezeCountText: String {
        L10n.format("common.freezes_count", freezeCount)
    }

    var freezeNoticeText: String? {
        guard let latestFreezeUsage else {
            return nil
        }

        let dateString = DailyFrameDateFormatter.localDateDisplayString(
            from: latestFreezeUsage.protectedLocalDateString
        )
        return L10n.format("profile.freeze.notice", dateString)
    }

    func load() async {
        await loadProfileStats()

        do {
            appSettings = try await appSettingsRepository.fetchSettings()
            syncPublishedState(from: appSettings)
            await refreshNotificationStatusMessage()
        } catch {
            notificationStatusMessage = L10n.string("error.notification.settings_load")
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
            _ = try await streakService.evaluateMissedYesterdayIfNeeded(now: dateProvider.currentDate())
            let state = try await streakStateRepository.fetchPrimaryState()
            currentStreak = max(state.currentStreak, 0)
            longestStreak = max(state.longestStreak, 0)
            freezeCount = max(state.freezeCount, 0)
            latestFreezeUsage = state.latestFreezeUsage
        } catch {
            currentStreak = 0
            longestStreak = 0
            freezeCount = 1
            latestFreezeUsage = nil
            didFail = true
        }

        profileStatsStatusMessage = didFail ? L10n.string("error.profile.stats_load") : nil
    }

    func exportArchive() async {
        guard isExportingArchive == false else { return }

        isExportingArchive = true
        exportedArchiveURL = nil
        exportStatusMessage = nil
        defer { isExportingArchive = false }

        do {
            let result = try await exportService.exportArchive()
            exportedArchiveURL = result.fileURL

            if result.warningCount > 0 {
                exportStatusMessage = L10n.format(
                    "profile.export.status.ready_with_warnings",
                    result.entryCount,
                    result.mediaFileCount,
                    result.warningCount
                )
            } else {
                exportStatusMessage = L10n.format(
                    "profile.export.status.ready",
                    result.entryCount,
                    result.mediaFileCount
                )
            }
        } catch {
            exportStatusMessage = L10n.string("error.export.archive")
        }
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
        reminderTime = Self.date(
            hour: components.hour,
            minute: components.minute,
            calendar: calendar,
            now: dateProvider.currentDate()
        )

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
            errorMessage = L10n.string("error.notification.time_save")
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
            errorMessage = L10n.string("error.notification.enable")
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
            errorMessage = L10n.string("error.notification.settings_save")
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
                ? L10n.format("profile.notification.status.scheduled", formattedReminderTime)
                : L10n.string("profile.notification.status.authorized")
        case .denied:
            notificationStatusMessage = L10n.string("profile.notification.status.denied")
        case .notDetermined:
            notificationStatusMessage = L10n.string("profile.notification.status.not_determined")
        @unknown default:
            notificationStatusMessage = L10n.string("profile.notification.status.unknown")
        }
    }

    private func syncPublishedState(from settings: AppSettings) {
        reminderEnabled = settings.reminderEnabled
        reminderTime = Self.date(
            hour: settings.reminderHour ?? 21,
            minute: settings.reminderMinute ?? 0,
            calendar: calendar,
            now: dateProvider.currentDate()
        )
    }

    private var formattedReminderTime: String {
        let components = reminderComponents(from: reminderTime)
        return String(format: "%02d:%02d", components.hour, components.minute)
    }

    private var permissionDeniedMessage: String {
        L10n.string("profile.notification.permission_denied")
    }

    private func reminderComponents(from date: Date) -> (hour: Int, minute: Int) {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return (
            hour: components.hour ?? appSettings.reminderHour ?? 21,
            minute: components.minute ?? appSettings.reminderMinute ?? 0
        )
    }

    private static func date(hour: Int, minute: Int, calendar: Calendar, now: Date) -> Date {
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components) ?? now
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
