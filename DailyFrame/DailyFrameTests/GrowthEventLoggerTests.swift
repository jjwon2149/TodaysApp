import XCTest
@testable import DailyFrame

final class GrowthEventLoggerTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()

        temporaryDirectory = FileManager.default.temporaryDirectory
            .appending(path: "DailyFrameGrowthEventTests-\(UUID().uuidString)")
    }

    override func tearDownWithError() throws {
        if let temporaryDirectory {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }

        temporaryDirectory = nil

        try super.tearDownWithError()
    }

    func testRecordWritesPrivacySafeDebugJSONL() throws {
        // Given
        let logger = GrowthEventLogger(
            applicationSupportDirectoryURL: temporaryDirectory,
            localDateProvider: { "2026-07-02" }
        )

        // When
        try logger.record(.visit, properties: ["surface": "app_launch"])
        try logger.record(.firstRecordSaved, properties: ["record_local_date": "2026-07-02"])

        // Then
        let records = try readRecords(from: logger.logFileURL)
        XCTAssertEqual(records.count, 2)
        XCTAssertEqual(records[0]["schema_version"] as? Int, 1)
        XCTAssertEqual(records[0]["event_name"] as? String, "visit")
        XCTAssertEqual(records[0]["funnel_stage"] as? String, "visit")
        XCTAssertEqual(records[0]["local_date"] as? String, "2026-07-02")
        XCTAssertEqual((records[0]["properties"] as? [String: String])?["surface"], "app_launch")
        XCTAssertNil(records[0]["user_id"])
        XCTAssertNil(records[0]["photo_path"])
        XCTAssertNil(records[0]["memo"])
    }

    func testRecordRejectsDisallowedPropertiesBeforeWriting() throws {
        // Given
        let logger = GrowthEventLogger(
            applicationSupportDirectoryURL: temporaryDirectory,
            localDateProvider: { "2026-07-02" }
        )

        // When / Then
        XCTAssertThrowsError(
            try logger.record(.photoSelected, properties: ["photo_path": "private/image.jpg"])
        )
        XCTAssertThrowsError(
            try logger.record(.visit, properties: ["surface": "app_launch", "memo": "private note"])
        )
        XCTAssertFalse(FileManager.default.fileExists(atPath: logger.logFileURL.path))
    }

    func testDisabledLoggerUsesReleaseNoOpSeam() throws {
        // Given
        let logger = GrowthEventLogger(
            applicationSupportDirectoryURL: temporaryDirectory,
            localDateProvider: { "2026-07-02" },
            isEnabled: false
        )

        // When
        try logger.record(.visit, properties: ["surface": "app_launch"])

        // Then
        XCTAssertFalse(FileManager.default.fileExists(atPath: logger.logFileURL.path))
    }

    func testRetentionEventsUseLocalDateSnapshotsOnly() throws {
        // Given
        let d1Logger = GrowthEventLogger(
            applicationSupportDirectoryURL: temporaryDirectory.appending(path: "d1"),
            localDateProvider: { "2026-07-03" }
        )
        let d7Logger = GrowthEventLogger(
            applicationSupportDirectoryURL: temporaryDirectory.appending(path: "d7"),
            localDateProvider: { "2026-07-09" }
        )

        // When
        try d1Logger.recordReturnIfEligible(activationLocalDateString: "2026-07-02")
        try d7Logger.recordReturnIfEligible(activationLocalDateString: "2026-07-02")

        // Then
        let d1Record = try XCTUnwrap(readRecords(from: d1Logger.logFileURL).first)
        let d7Record = try XCTUnwrap(readRecords(from: d7Logger.logFileURL).first)
        XCTAssertEqual(d1Record["event_name"] as? String, "d1_return")
        XCTAssertEqual(d7Record["event_name"] as? String, "d7_return")
        XCTAssertEqual(
            d1Record["properties"] as? [String: String],
            [
                "activation_local_date": "2026-07-02",
                "day_offset": "1",
                "return_local_date": "2026-07-03"
            ]
        )
        XCTAssertEqual(
            d7Record["properties"] as? [String: String],
            [
                "activation_local_date": "2026-07-02",
                "day_offset": "7",
                "return_local_date": "2026-07-09"
            ]
        )
    }

    func testMalformedLocalDateDoesNotWriteRetentionEvent() throws {
        // Given
        let logger = GrowthEventLogger(
            applicationSupportDirectoryURL: temporaryDirectory,
            localDateProvider: { "2026-07-03" }
        )

        // When / Then
        XCTAssertThrowsError(
            try logger.recordReturnIfEligible(activationLocalDateString: "2026/07/02")
        )
        XCTAssertFalse(FileManager.default.fileExists(atPath: logger.logFileURL.path))
    }

    private func readRecords(from fileURL: URL) throws -> [[String: Any]] {
        let text = try String(contentsOf: fileURL, encoding: .utf8)
        return try text.split(separator: "\n").map { line in
            let data = Data(String(line).utf8)
            let object = try JSONSerialization.jsonObject(with: data)
            return try XCTUnwrap(object as? [String: Any])
        }
    }
}
