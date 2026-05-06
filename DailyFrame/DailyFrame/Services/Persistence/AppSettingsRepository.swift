import Foundation

struct AppSettingsRepository {
    let store: PersistenceStore

    init(store: PersistenceStore = .shared) {
        self.store = store
    }

    func fetchSettings() async throws -> AppSettings {
        try await store.load().settings
    }

    func save(_ settings: AppSettings) async throws {
        try await store.update { snapshot in
            snapshot.settings = settings
        }
    }

    func updateNotificationSettings(
        reminderEnabled: Bool,
        reminderHour: Int?,
        reminderMinute: Int?,
        notificationsPermissionPrompted: Bool
    ) async throws -> AppSettings {
        var updatedSettings = AppSettings()

        try await store.update { snapshot in
            snapshot.settings.reminderEnabled = reminderEnabled
            snapshot.settings.reminderHour = reminderHour
            snapshot.settings.reminderMinute = reminderMinute
            snapshot.settings.notificationsPermissionPrompted = notificationsPermissionPrompted
            updatedSettings = snapshot.settings
        }

        return updatedSettings
    }
}
