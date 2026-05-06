import Foundation

struct AppSettings: Codable, Identifiable {
    var id: UUID
    var reminderEnabled: Bool
    var reminderHour: Int?
    var reminderMinute: Int?
    var notificationsPermissionPrompted: Bool
    var cameraPermissionPrompted: Bool
    var photoLibraryPermissionPrompted: Bool
    var autoApplyFreeze: Bool
    var hapticsEnabled: Bool

    init(
        id: UUID = UUID(),
        reminderEnabled: Bool = false,
        reminderHour: Int? = 21,
        reminderMinute: Int? = 0,
        notificationsPermissionPrompted: Bool = false,
        cameraPermissionPrompted: Bool = false,
        photoLibraryPermissionPrompted: Bool = false,
        autoApplyFreeze: Bool = true,
        hapticsEnabled: Bool = true
    ) {
        self.id = id
        self.reminderEnabled = reminderEnabled
        self.reminderHour = reminderHour
        self.reminderMinute = reminderMinute
        self.notificationsPermissionPrompted = notificationsPermissionPrompted
        self.cameraPermissionPrompted = cameraPermissionPrompted
        self.photoLibraryPermissionPrompted = photoLibraryPermissionPrompted
        self.autoApplyFreeze = autoApplyFreeze
        self.hapticsEnabled = hapticsEnabled
    }
}
