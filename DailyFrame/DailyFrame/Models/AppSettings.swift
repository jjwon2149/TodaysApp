import Foundation

enum ICloudSyncPolicy: String, Codable, Equatable {
    case notSetUp
    case enabled
    case disabled

    var allowsSync: Bool {
        self == .enabled
    }
}

struct AppSettings: Codable, Identifiable {
    private enum CodingKeys: String, CodingKey {
        case id
        case reminderEnabled
        case reminderHour
        case reminderMinute
        case notificationsPermissionPrompted
        case cameraPermissionPrompted
        case photoLibraryPermissionPrompted
        case autoApplyFreeze
        case hapticsEnabled
        case iCloudSyncPolicy
        case iCloudSyncDisclosureSeenAtUTC
    }

    var id: UUID
    var reminderEnabled: Bool
    var reminderHour: Int?
    var reminderMinute: Int?
    var notificationsPermissionPrompted: Bool
    var cameraPermissionPrompted: Bool
    var photoLibraryPermissionPrompted: Bool
    var autoApplyFreeze: Bool
    var hapticsEnabled: Bool
    var iCloudSyncPolicy: ICloudSyncPolicy
    var iCloudSyncDisclosureSeenAtUTC: Date?

    var effectiveICloudSyncPolicy: ICloudSyncPolicy {
        if iCloudSyncPolicy == .enabled && iCloudSyncDisclosureSeenAtUTC == nil {
            return .notSetUp
        }

        return iCloudSyncPolicy
    }

    init(
        id: UUID = UUID(),
        reminderEnabled: Bool = false,
        reminderHour: Int? = 21,
        reminderMinute: Int? = 0,
        notificationsPermissionPrompted: Bool = false,
        cameraPermissionPrompted: Bool = false,
        photoLibraryPermissionPrompted: Bool = false,
        autoApplyFreeze: Bool = true,
        hapticsEnabled: Bool = true,
        iCloudSyncPolicy: ICloudSyncPolicy = .notSetUp,
        iCloudSyncDisclosureSeenAtUTC: Date? = nil
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
        self.iCloudSyncPolicy = iCloudSyncPolicy
        self.iCloudSyncDisclosureSeenAtUTC = iCloudSyncDisclosureSeenAtUTC
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        reminderEnabled = try container.decodeIfPresent(Bool.self, forKey: .reminderEnabled) ?? false
        reminderHour = try container.decodeIfPresent(Int.self, forKey: .reminderHour) ?? 21
        reminderMinute = try container.decodeIfPresent(Int.self, forKey: .reminderMinute) ?? 0
        notificationsPermissionPrompted = try container.decodeIfPresent(Bool.self, forKey: .notificationsPermissionPrompted) ?? false
        cameraPermissionPrompted = try container.decodeIfPresent(Bool.self, forKey: .cameraPermissionPrompted) ?? false
        photoLibraryPermissionPrompted = try container.decodeIfPresent(Bool.self, forKey: .photoLibraryPermissionPrompted) ?? false
        autoApplyFreeze = try container.decodeIfPresent(Bool.self, forKey: .autoApplyFreeze) ?? true
        hapticsEnabled = try container.decodeIfPresent(Bool.self, forKey: .hapticsEnabled) ?? true
        iCloudSyncPolicy = try container.decodeIfPresent(ICloudSyncPolicy.self, forKey: .iCloudSyncPolicy) ?? .notSetUp
        iCloudSyncDisclosureSeenAtUTC = try container.decodeIfPresent(Date.self, forKey: .iCloudSyncDisclosureSeenAtUTC)
    }
}
