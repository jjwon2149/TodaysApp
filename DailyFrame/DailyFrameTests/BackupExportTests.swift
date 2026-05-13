import XCTest
@testable import DailyFrame

final class BackupExportTests: XCTestCase {
    private var temporaryDirectory: URL!
    private var entriesDirectory: URL!
    private var store: PersistenceStore!
    private var entryRepository: EntryRepository!
    private var imageStorageService: ImageStorageService!

    override func setUp() async throws {
        try await super.setUp()

        temporaryDirectory = FileManager.default.temporaryDirectory
            .appending(path: "DailyFrameBackupExportTests-\(UUID().uuidString)")
        entriesDirectory = temporaryDirectory.appending(path: "Entries")
        try FileManager.default.createDirectory(at: entriesDirectory, withIntermediateDirectories: true)

        store = PersistenceStore(baseDirectoryURL: temporaryDirectory)
        entryRepository = EntryRepository(store: store)
        imageStorageService = ImageStorageService(entriesDirectoryURL: entriesDirectory)
    }

    override func tearDown() async throws {
        if let temporaryDirectory {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }

        imageStorageService = nil
        entryRepository = nil
        store = nil
        entriesDirectory = nil
        temporaryDirectory = nil

        try await super.tearDown()
    }

    func testStoredMediaReferencesArePortableFilenamesAndLegacyAbsolutePathsResolve() throws {
        let fileName = "2026-05-13-photo.jpg"
        let fileURL = try imageStorageService.saveImageData(Data([1, 2, 3]), fileName: fileName)

        XCTAssertEqual(try imageStorageService.mediaReference(for: fileURL), fileName)

        let staleAbsolutePath = "/var/mobile/Containers/Data/Application/OLD/Library/Application Support/DailyFrame/Entries/\(fileName)"
        XCTAssertEqual(imageStorageService.resolvedFileURL(for: staleAbsolutePath)?.path, fileURL.path)
    }

    func testLaunchMaintenanceMigratesLegacyAbsoluteMediaReferences() async throws {
        let imageURL = entriesDirectory.appending(path: "legacy-image.jpg")
        let thumbnailURL = entriesDirectory.appending(path: "legacy-thumbnail.jpg")
        let orphanURL = entriesDirectory.appending(path: "orphan.jpg")
        try Data([1, 2, 3]).write(to: imageURL)
        try Data([4, 5, 6]).write(to: thumbnailURL)
        try Data([7, 8, 9]).write(to: orphanURL)

        try await seed(entries: [
            entry(
                "2026-05-13",
                imageLocalPath: "/old/container/Entries/legacy-image.jpg",
                thumbnailLocalPath: "file:///old/container/Entries/legacy-thumbnail.jpg"
            )
        ])

        let result = await imageStorageService.performLaunchMaintenance(entryRepository: entryRepository)
        let migratedEntry = try await entryRepository.fetchEntry(for: "2026-05-13")

        XCTAssertEqual(result.migratedReferenceCount, 2)
        XCTAssertEqual(result.deletedOrphanFileCount, 1)
        XCTAssertEqual(result.failureCount, 0)
        XCTAssertEqual(migratedEntry?.imageLocalPath, "legacy-image.jpg")
        XCTAssertEqual(migratedEntry?.thumbnailLocalPath, "legacy-thumbnail.jpg")
        XCTAssertTrue(FileManager.default.fileExists(atPath: imageURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: thumbnailURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: orphanURL.path))
    }

    func testThumbnailResolutionFallsBackToOriginalImage() throws {
        let imageURL = entriesDirectory.appending(path: "fallback-image.jpg")
        try Data([1, 2, 3]).write(to: imageURL)

        let resolvedURL = imageStorageService.resolvedThumbnailFileURL(
            thumbnailReference: "missing-thumbnail.jpg",
            imageReference: "fallback-image.jpg"
        )

        XCTAssertEqual(resolvedURL?.path, imageURL.path)
    }

    func testExportArchiveContainsManifestMediaAndMissingThumbnailWarning() async throws {
        let generatedAt = Date(timeIntervalSince1970: 1_778_688_000)
        let imageURL = entriesDirectory.appending(path: "export-image.jpg")
        try Data([0xff, 0xd8, 0xff, 0xd9]).write(to: imageURL)
        try await seed(entries: [
            entry(
                "2026-05-13",
                imageLocalPath: "/stale/container/Entries/export-image.jpg",
                thumbnailLocalPath: "/stale/container/Entries/export-thumbnail.jpg"
            )
        ])
        let exportService = ExportService(
            entryRepository: entryRepository,
            imageStorageService: imageStorageService,
            nowProvider: { generatedAt }
        )

        let result = try await exportService.exportArchive()
        defer {
            try? FileManager.default.removeItem(at: result.fileURL)
        }

        XCTAssertTrue(FileManager.default.fileExists(atPath: result.fileURL.path))
        XCTAssertEqual(result.entryCount, 1)
        XCTAssertEqual(result.mediaFileCount, 1)
        XCTAssertEqual(result.warningCount, 1)
        XCTAssertEqual(result.manifest.entries.first?.media.imagePath, "Media/export-image.jpg")
        XCTAssertEqual(result.manifest.entries.first?.media.thumbnailPath, "Media/export-image.jpg")
        XCTAssertEqual(result.manifest.warnings.first?.code, "thumbnail_missing_using_image")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let manifestData = try encoder.encode(result.manifest)
        let manifestString = String(decoding: manifestData, as: UTF8.self)
        XCTAssertFalse(manifestString.contains(temporaryDirectory.path))
        XCTAssertFalse(manifestString.contains("/stale/container"))

        let archiveData = try Data(contentsOf: result.fileURL)
        let archiveString = String(decoding: archiveData, as: UTF8.self)
        XCTAssertTrue(archiveString.contains("manifest.json"))
        XCTAssertTrue(archiveString.contains("Media/export-image.jpg"))
    }

    private func seed(entries: [DailyPhotoEntry]) async throws {
        let snapshot = AppStateSnapshot(
            userProfile: UserProfile(),
            entries: entries,
            streakState: StreakState(),
            settings: AppSettings(),
            missionHistory: []
        )

        try await store.save(snapshot)
    }

    private func entry(
        _ localDateString: String,
        imageLocalPath: String,
        thumbnailLocalPath: String? = nil
    ) -> DailyPhotoEntry {
        DailyPhotoEntry(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID(),
            localDateString: localDateString,
            createdAtUTC: Date(timeIntervalSince1970: 1_778_688_000),
            updatedAtUTC: Date(timeIntervalSince1970: 1_778_688_100),
            timezoneIdentifier: "Asia/Seoul",
            timezoneOffsetMinutes: 540,
            imageLocalPath: imageLocalPath,
            thumbnailLocalPath: thumbnailLocalPath,
            memo: "Export test",
            moodCode: "좋음",
            missionId: "mission-test",
            missionCompleted: true,
            sourceType: "test"
        )
    }
}
