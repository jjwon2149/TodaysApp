import Foundation

enum GrowthEventName: String, CaseIterable {
    case visit
    case onboardingStart = "onboarding_start"
    case firstRecordStart = "first_record_start"
    case photoSelected = "photo_selected"
    case firstRecordSaved = "first_record_saved"
    case completionViewed = "completion_viewed"
    case reminderEnabled = "reminder_enabled"
    case d1Return = "d1_return"
    case d7Return = "d7_return"
    case shareTapped = "share_tapped"
    case paymentInterestTapped = "payment_interest_tapped"

    var funnelStage: String {
        switch self {
        case .visit:
            "visit"
        case .onboardingStart, .firstRecordStart, .photoSelected:
            "start"
        case .firstRecordSaved, .completionViewed:
            "activation"
        case .reminderEnabled, .d1Return, .d7Return:
            "return"
        case .shareTapped:
            "share_placeholder"
        case .paymentInterestTapped:
            "payment_placeholder"
        }
    }

    var allowedPropertyKeys: Set<String> {
        switch self {
        case .visit, .onboardingStart, .firstRecordStart:
            ["surface"]
        case .photoSelected:
            ["photo_source"]
        case .firstRecordSaved, .completionViewed:
            ["record_local_date"]
        case .reminderEnabled:
            ["reminder_status"]
        case .d1Return, .d7Return:
            ["activation_local_date", "day_offset", "return_local_date"]
        case .shareTapped, .paymentInterestTapped:
            ["placeholder_context", "surface"]
        }
    }
}

enum GrowthEventLoggerError: Error, Equatable {
    case disallowedProperty(eventName: String, key: String)
    case invalidLocalDate(String)
    case unsafePropertyValue(key: String, value: String)
}

struct GrowthEventLogger {
    static let schemaVersion = 1

    let applicationSupportDirectoryURL: URL
    let localDateProvider: () -> String
    let isEnabled: Bool

    var logFileURL: URL {
        applicationSupportDirectoryURL.appending(path: "growth-events.jsonl")
    }

    init(
        applicationSupportDirectoryURL: URL? = nil,
        localDateProvider: @escaping () -> String = GrowthEventLogger.currentLocalDateString,
        isEnabled: Bool = GrowthEventLogger.defaultIsEnabled
    ) {
        self.applicationSupportDirectoryURL = applicationSupportDirectoryURL ?? Self.defaultApplicationSupportDirectoryURL()
        self.localDateProvider = localDateProvider
        self.isEnabled = isEnabled
    }

    func record(_ eventName: GrowthEventName, properties: [String: String] = [:]) throws {
        #if DEBUG
        guard isEnabled else {
            return
        }

        let localDateString = try Self.validLocalDateString(localDateProvider())
        try Self.validate(properties: properties, for: eventName)

        let record: [String: Any] = [
            "schema_version": Self.schemaVersion,
            "event_name": eventName.rawValue,
            "funnel_stage": eventName.funnelStage,
            "local_date": localDateString,
            "properties": properties
        ]
        let data = try JSONSerialization.data(withJSONObject: record, options: [.sortedKeys])
        try appendLine(data)
        #else
        _ = eventName
        _ = properties
        #endif
    }

    func recordReturnIfEligible(activationLocalDateString: String) throws {
        #if DEBUG
        guard isEnabled else {
            return
        }

        let activationDate = try Self.date(from: activationLocalDateString)
        let returnLocalDateString = try Self.validLocalDateString(localDateProvider())
        let returnDate = try Self.date(from: returnLocalDateString)
        let dayOffset = Self.calendar.dateComponents([.day], from: activationDate, to: returnDate).day

        switch dayOffset {
        case 1:
            try record(
                .d1Return,
                properties: [
                    "activation_local_date": activationLocalDateString,
                    "day_offset": "1",
                    "return_local_date": returnLocalDateString
                ]
            )
        case 7:
            try record(
                .d7Return,
                properties: [
                    "activation_local_date": activationLocalDateString,
                    "day_offset": "7",
                    "return_local_date": returnLocalDateString
                ]
            )
        default:
            return
        }
        #else
        _ = activationLocalDateString
        #endif
    }

    #if DEBUG
    private func appendLine(_ data: Data) throws {
        var line = data
        line.append(0x0A)

        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: applicationSupportDirectoryURL.path) == false {
            try fileManager.createDirectory(at: applicationSupportDirectoryURL, withIntermediateDirectories: true)
        }

        if fileManager.fileExists(atPath: logFileURL.path) {
            let fileHandle = try FileHandle(forWritingTo: logFileURL)
            defer { try? fileHandle.close() }
            try fileHandle.seekToEnd()
            try fileHandle.write(contentsOf: line)
        } else {
            try line.write(to: logFileURL, options: [.atomic])
        }
    }

    private static func validate(properties: [String: String], for eventName: GrowthEventName) throws {
        for (key, value) in properties {
            guard eventName.allowedPropertyKeys.contains(key) else {
                throw GrowthEventLoggerError.disallowedProperty(eventName: eventName.rawValue, key: key)
            }

            guard isSafePropertyValue(value) else {
                throw GrowthEventLoggerError.unsafePropertyValue(key: key, value: value)
            }

            if key.hasSuffix("_local_date") {
                _ = try validLocalDateString(value)
            }
        }
    }

    private static func isSafePropertyValue(_ value: String) -> Bool {
        guard value.isEmpty == false, value.count <= 64 else {
            return false
        }

        return value.unicodeScalars.allSatisfy { scalar in
            (48...57).contains(scalar.value)
                || (65...90).contains(scalar.value)
                || (97...122).contains(scalar.value)
                || scalar == "_"
                || scalar == "-"
                || scalar == ":"
        }
    }

    private static func validLocalDateString(_ value: String) throws -> String {
        _ = try date(from: value)
        return value
    }

    private static func date(from value: String) throws -> Date {
        let parts = value.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3,
              parts[0].count == 4,
              parts[1].count == 2,
              parts[2].count == 2,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2])
        else {
            throw GrowthEventLoggerError.invalidLocalDate(value)
        }

        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = year
        components.month = month
        components.day = day

        guard let date = calendar.date(from: components) else {
            throw GrowthEventLoggerError.invalidLocalDate(value)
        }

        let resolved = calendar.dateComponents([.year, .month, .day], from: date)
        guard resolved.year == year,
              resolved.month == month,
              resolved.day == day
        else {
            throw GrowthEventLoggerError.invalidLocalDate(value)
        }

        return date
    }
    #endif

    private static func currentLocalDateString() -> String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }

    private static func defaultApplicationSupportDirectoryURL() -> URL {
        guard let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return FileManager.default.temporaryDirectory.appending(path: "DailyFrame")
        }

        return directory.appending(path: "DailyFrame")
    }

    private static var defaultIsEnabled: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }

    #if DEBUG
    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }
    #endif
}
