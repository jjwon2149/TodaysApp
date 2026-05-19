import XCTest
@testable import DailyFrame

final class CloudKitSyncServiceTests: XCTestCase {
    private var temporaryDirectory: URL!
    private var entriesDirectory: URL!
    private var remoteAssetsDirectory: URL!
    private var store: PersistenceStore!
    private var entryRepository: EntryRepository!
    private var imageStorageService: ImageStorageService!
    private var appSettingsRepository: AppSettingsRepository!
    private var remoteStore: FakeCloudSyncRemoteStore!

    override func setUp() async throws {
        try await super.setUp()

        temporaryDirectory = FileManager.default.temporaryDirectory
            .appending(path: "DailyFrameCloudKitSyncTests-\(UUID().uuidString)")
        entriesDirectory = temporaryDirectory.appending(path: "Entries")
        remoteAssetsDirectory = temporaryDirectory.appending(path: "RemoteAssets")
        try FileManager.default.createDirectory(at: entriesDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: remoteAssetsDirectory, withIntermediateDirectories: true)

        store = PersistenceStore(baseDirectoryURL: temporaryDirectory)
        entryRepository = EntryRepository(store: store)
        imageStorageService = ImageStorageService(entriesDirectoryURL: entriesDirectory)
        appSettingsRepository = AppSettingsRepository(store: store)
        remoteStore = FakeCloudSyncRemoteStore()
        try await seed()
    }

    override func tearDown() async throws {
        if let temporaryDirectory {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }

        remoteStore = nil
        appSettingsRepository = nil
        imageStorageService = nil
        entryRepository = nil
        store = nil
        remoteAssetsDirectory = nil
        entriesDirectory = nil
        temporaryDirectory = nil

        try await super.tearDown()
    }

    func testRemoteEntryRestoresLocalEntryAndCopiesMediaByPortableFileName() async throws {
        let imageURL = remoteAssetsDirectory.appending(path: "remote-image.jpg")
        let thumbnailURL = remoteAssetsDirectory.appending(path: "remote-thumbnail.jpg")
        try Data([1, 2, 3]).write(to: imageURL)
        try Data([4, 5, 6]).write(to: thumbnailURL)

        remoteStore.remoteEntries = [
            cloudRecord("2026-05-12", updatedAtUTC: instant(200), memo: "remote memo")
        ]
        remoteStore.remoteMedia = [
            CloudSyncMediaAsset(
                localDateString: "2026-05-12",
                role: .image,
                fileName: "remote-image.jpg",
                updatedAtUTC: instant(200),
                assetFileURL: imageURL
            ),
            CloudSyncMediaAsset(
                localDateString: "2026-05-12",
                role: .thumbnail,
                fileName: "remote-thumbnail.jpg",
                updatedAtUTC: instant(200),
                assetFileURL: thumbnailURL
            )
        ]

        let service = makeService()
        let status = await service.synchronize(trigger: .manual)
        let restoredEntry = try await entryRepository.fetchEntry(for: "2026-05-12")

        XCTAssertEqual(restoredEntry?.memo, "remote memo")
        XCTAssertEqual(restoredEntry?.imageLocalPath, "remote-image.jpg")
        XCTAssertEqual(restoredEntry?.thumbnailLocalPath, "remote-thumbnail.jpg")
        XCTAssertTrue(FileManager.default.fileExists(atPath: entriesDirectory.appending(path: "remote-image.jpg").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: entriesDirectory.appending(path: "remote-thumbnail.jpg").path))
        XCTAssertEqual(status.downloadedEntryCount, 1)
        XCTAssertEqual(status.downloadedMediaCount, 2)
    }

    func testLocalUploadUsesResolvedMediaURLInsteadOfStaleAbsolutePath() async throws {
        let fileName = "2026-05-13-local.jpg"
        let localImageURL = entriesDirectory.appending(path: fileName)
        try Data([1, 2, 3]).write(to: localImageURL)
        let stalePath = "/var/mobile/Containers/Data/Application/OLD/Library/Application Support/DailyFrame/Entries/\(fileName)"
        try await seed(entries: [
            localEntry("2026-05-13", updatedAtUTC: instant(300), imageLocalPath: stalePath)
        ])

        let service = makeService()
        let status = await service.synchronize(trigger: .manual)

        XCTAssertEqual(remoteStore.savedEntries.map(\.localDateString), ["2026-05-13"])
        XCTAssertEqual(remoteStore.savedMedia.count, 1)
        XCTAssertEqual(remoteStore.savedMedia.first?.fileName, fileName)
        XCTAssertEqual(remoteStore.savedMedia.first?.assetFileURL?.path, localImageURL.path)
        XCTAssertFalse(remoteStore.savedMedia.first?.assetFileURL?.path.contains("/OLD/") == true)
        XCTAssertEqual(status.uploadedEntryCount, 1)
        XCTAssertEqual(status.uploadedMediaCount, 1)
    }

    func testUnavailableICloudDoesNotBlockOrMutateLocalEntries() async throws {
        remoteStore.accountStateValue = .unavailable(.noAccount)
        try await seed(entries: [
            localEntry("2026-05-14", updatedAtUTC: instant(100), imageLocalPath: "missing-local.jpg")
        ])

        let service = makeService()
        let status = await service.synchronize(trigger: .manual)
        let activeEntries = try await entryRepository.fetchAllActiveEntries()

        XCTAssertEqual(activeEntries.map(\.localDateString), ["2026-05-14"])
        XCTAssertTrue(remoteStore.savedEntries.isEmpty)
        XCTAssertTrue(remoteStore.savedMedia.isEmpty)

        if case .unavailable(.noAccount) = status.state {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected no-account unavailable status, got \(status.state)")
        }
    }

    func testNewerRemoteTombstoneWinsOverOlderLocalEdit() async throws {
        try await seed(entries: [
            localEntry("2026-05-15", updatedAtUTC: instant(100), imageLocalPath: "local.jpg")
        ])
        remoteStore.remoteEntries = [
            cloudRecord("2026-05-15", updatedAtUTC: instant(200), memo: "deleted", isDeleted: true)
        ]

        let service = makeService()
        let status = await service.synchronize(trigger: .manual)
        let activeEntry = try await entryRepository.fetchEntry(for: "2026-05-15")
        let rawEntry = try await store.load().entries.first { $0.localDateString == "2026-05-15" }

        XCTAssertNil(activeEntry)
        XCTAssertEqual(rawEntry?.isDeleted, true)
        XCTAssertEqual(status.downloadedEntryCount, 1)
    }

    func testEnabledPolicyWithoutDisclosureSkipsRemoteWorkBeforeDisclosure() async throws {
        try await seed(
            entries: [
                localEntry("2026-05-16", updatedAtUTC: instant(100), imageLocalPath: "local.jpg")
            ],
            settings: AppSettings(iCloudSyncPolicy: .enabled)
        )

        let service = makeService()
        let status = await service.synchronize(trigger: .launch)
        let activeEntries = try await entryRepository.fetchAllActiveEntries()

        XCTAssertEqual(activeEntries.map(\.localDateString), ["2026-05-16"])
        XCTAssertEqual(remoteStore.accountStateCallCount, 0)
        XCTAssertTrue(remoteStore.savedEntries.isEmpty)
        XCTAssertTrue(remoteStore.savedMedia.isEmpty)

        if case .notSetUp = status.state {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected not-set-up status, got \(status.state)")
        }
    }

    func testDisabledPolicyKeepsLocalChangeLocalAndDoesNotUpload() async throws {
        try await seed(
            entries: [
                localEntry("2026-05-17", updatedAtUTC: instant(100), imageLocalPath: "local.jpg", isDeleted: true)
            ],
            settings: AppSettings(
                iCloudSyncPolicy: .disabled,
                iCloudSyncDisclosureSeenAtUTC: instant(10)
            )
        )

        let service = makeService()
        let status = await service.synchronize(trigger: .localChange)
        let rawEntries = try await store.load().entries

        XCTAssertEqual(rawEntries.map(\.localDateString), ["2026-05-17"])
        XCTAssertEqual(rawEntries.first?.isDeleted, true)
        XCTAssertEqual(remoteStore.accountStateCallCount, 0)
        XCTAssertTrue(remoteStore.savedEntries.isEmpty)
        XCTAssertTrue(remoteStore.savedMedia.isEmpty)

        if case .disabled = status.state {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected disabled status, got \(status.state)")
        }
    }

    @MainActor
    func testProfileSyncStatusMessageMappingCoversPolicyAndFallbackStates() {
        let noAccount = CloudSyncStatus(
            state: .unavailable(.noAccount),
            lastSyncedAtUTC: nil,
            uploadedEntryCount: 0,
            downloadedEntryCount: 0,
            uploadedMediaCount: 0,
            downloadedMediaCount: 0,
            skippedMediaCount: 0
        )
        let offline = CloudSyncStatus(
            state: .unavailable(.temporarilyUnavailable),
            lastSyncedAtUTC: nil,
            uploadedEntryCount: 0,
            downloadedEntryCount: 0,
            uploadedMediaCount: 0,
            downloadedMediaCount: 0,
            skippedMediaCount: 0
        )
        let failed = CloudSyncStatus(
            state: .failed("network"),
            lastSyncedAtUTC: nil,
            uploadedEntryCount: 0,
            downloadedEntryCount: 0,
            uploadedMediaCount: 0,
            downloadedMediaCount: 0,
            skippedMediaCount: 0
        )

        XCTAssertEqual(
            ProfileViewModel.syncStatusMessage(for: .idle, policy: .notSetUp),
            L10n.string("profile.sync.status.not_set_up")
        )
        XCTAssertEqual(
            ProfileViewModel.syncStatusMessage(for: .idle, policy: .disabled),
            L10n.string("profile.sync.status.disabled")
        )
        XCTAssertEqual(
            ProfileViewModel.syncStatusMessage(for: .idle, policy: .enabled),
            L10n.string("profile.sync.status.idle")
        )
        XCTAssertEqual(
            ProfileViewModel.syncStatusMessage(for: noAccount, policy: .enabled),
            L10n.string("profile.sync.status.no_account")
        )
        XCTAssertEqual(
            ProfileViewModel.syncStatusMessage(for: offline, policy: .enabled),
            L10n.string("profile.sync.status.unavailable")
        )
        XCTAssertEqual(
            ProfileViewModel.syncStatusMessage(for: failed, policy: .enabled),
            L10n.string("profile.sync.status.failed")
        )
    }

    private func makeService() -> CloudKitSyncService {
        CloudKitSyncService(
            remoteStore: remoteStore,
            entryRepository: entryRepository,
            imageStorageService: imageStorageService,
            appSettingsRepository: appSettingsRepository,
            nowProvider: { self.instant(999) }
        )
    }

    private func seed(
        entries: [DailyPhotoEntry] = [],
        settings: AppSettings = AppSettings(
            iCloudSyncPolicy: .enabled,
            iCloudSyncDisclosureSeenAtUTC: Date(timeIntervalSince1970: 1_778_688_001)
        )
    ) async throws {
        let snapshot = AppStateSnapshot(
            userProfile: UserProfile(),
            entries: entries,
            streakState: StreakState(),
            settings: settings,
            missionHistory: []
        )

        try await store.save(snapshot)
    }

    private func localEntry(
        _ localDateString: String,
        updatedAtUTC: Date,
        imageLocalPath: String,
        isDeleted: Bool = false
    ) -> DailyPhotoEntry {
        DailyPhotoEntry(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID(),
            localDateString: localDateString,
            createdAtUTC: instant(50),
            updatedAtUTC: updatedAtUTC,
            timezoneIdentifier: "Asia/Seoul",
            timezoneOffsetMinutes: 540,
            imageLocalPath: imageLocalPath,
            memo: "local memo",
            sourceType: "test",
            isDeleted: isDeleted
        )
    }

    private func cloudRecord(
        _ localDateString: String,
        updatedAtUTC: Date,
        memo: String? = nil,
        isDeleted: Bool = false
    ) -> CloudSyncEntryRecord {
        CloudSyncEntryRecord(
            localDateString: localDateString,
            createdAtUTC: instant(50),
            updatedAtUTC: updatedAtUTC,
            timezoneIdentifier: "Asia/Seoul",
            timezoneOffsetMinutes: 540,
            memo: memo,
            moodCode: nil,
            missionId: "mission-test",
            missionCompleted: true,
            sourceType: "test",
            isDeleted: isDeleted
        )
    }

    private func instant(_ offset: TimeInterval) -> Date {
        Date(timeIntervalSince1970: 1_778_688_000 + offset)
    }
}

private final class FakeCloudSyncRemoteStore: CloudSyncRemoteStore {
    var accountStateValue: CloudSyncAccountState = .available
    var remoteEntries: [CloudSyncEntryRecord] = []
    var remoteMedia: [CloudSyncMediaAsset] = []
    private(set) var accountStateCallCount = 0
    private(set) var savedEntries: [CloudSyncEntryRecord] = []
    private(set) var savedMedia: [CloudSyncMediaAsset] = []

    func accountState() async throws -> CloudSyncAccountState {
        accountStateCallCount += 1
        return accountStateValue
    }

    func fetchEntries() async throws -> [CloudSyncEntryRecord] {
        remoteEntries
    }

    func fetchMedia() async throws -> [CloudSyncMediaAsset] {
        remoteMedia
    }

    func save(entry: CloudSyncEntryRecord) async throws {
        savedEntries.append(entry)
    }

    func save(media: CloudSyncMediaAsset) async throws {
        savedMedia.append(media)
    }
}
