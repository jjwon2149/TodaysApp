import XCTest
import UIKit
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
    private var remoteStoreFactoryCallCount = 0

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
        remoteStoreFactoryCallCount = 0
        try await seed()
    }

    override func tearDown() async throws {
        if let temporaryDirectory {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }

        remoteStore = nil
        remoteStoreFactoryCallCount = 0
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
        try validJPEGData(color: .red).write(to: imageURL)
        try validJPEGData(color: .blue).write(to: thumbnailURL)

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
        XCTAssertNotNil(restoredEntry?.imageLocalPath)
        XCTAssertNotNil(restoredEntry?.thumbnailLocalPath)
        XCTAssertNotNil(restoredEntry.flatMap { imageStorageService.resolvedFileURL(for: $0.imageLocalPath) })
        XCTAssertNotNil(restoredEntry?.thumbnailLocalPath.flatMap { imageStorageService.resolvedFileURL(for: $0) })
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

    func testEqualMetadataRetriesMissingRemoteMediaAfterRestart() async throws {
        let imageName = "equal-retry.jpg"
        try validJPEGData(color: .green).write(to: entriesDirectory.appending(path: imageName))
        let entry = localEntry("2026-05-18", updatedAtUTC: instant(400), imageLocalPath: imageName)
        try await seed(entries: [entry])
        remoteStore.remoteEntries = [cloudRecord("2026-05-18", updatedAtUTC: instant(400), memo: "local memo")]

        remoteStore.mediaSaveFailuresRemaining = 1
        let firstStatus = await makeService().synchronize(trigger: .manual)
        XCTAssertEqual(firstStatus.state, .incomplete)
        XCTAssertEqual(firstStatus.skippedMediaCount, 1)
        XCTAssertTrue(remoteStore.remoteMedia.isEmpty)

        let secondStatus = await makeService().synchronize(trigger: .launch)
        XCTAssertEqual(secondStatus.state, .synced)
        XCTAssertEqual(secondStatus.uploadedMediaCount, 1)
        XCTAssertEqual(remoteStore.remoteMedia.first?.role, .image)

        let savedMediaCount = remoteStore.savedMedia.count
        let thirdStatus = await makeService().synchronize(trigger: .foreground)
        XCTAssertEqual(thirdStatus.state, .synced)
        XCTAssertEqual(thirdStatus.uploadedMediaCount, 0)
        XCTAssertEqual(thirdStatus.downloadedMediaCount, 0)
        XCTAssertEqual(remoteStore.savedMedia.count, savedMediaCount)
    }

    func testMetadataForAllEntriesUploadsBeforeAnyMedia() async throws {
        for (date, name) in [("2026-05-19", "one.jpg"), ("2026-05-20", "two.jpg")] {
            try validJPEGData(color: .orange).write(to: entriesDirectory.appending(path: name))
            try await entryRepository.upsert(localEntry(date, updatedAtUTC: instant(500), imageLocalPath: name))
        }

        _ = await makeService().synchronize(trigger: .manual)

        let lastEntryIndex = try XCTUnwrap(remoteStore.events.lastIndex { $0.hasPrefix("entry:") })
        let firstMediaIndex = try XCTUnwrap(remoteStore.events.firstIndex { $0.hasPrefix("media:") })
        XCTAssertLessThan(lastEntryIndex, firstMediaIndex)
    }

    func testEditDuringMetadataUploadUploadsNewMetadataBeforeNewMedia() async throws {
        let originalName = "before-edit.jpg"
        let editedName = "after-edit.jpg"
        try validJPEGData(color: .brown).write(to: entriesDirectory.appending(path: originalName))
        try validJPEGData(color: .magenta).write(to: entriesDirectory.appending(path: editedName))
        let original = localEntry("2026-05-25", updatedAtUTC: instant(100), imageLocalPath: originalName)
        try await seed(entries: [original])
        remoteStore.onSaveEntry = { [entryRepository] record in
            guard record.updatedAtUTC == self.instant(100) else { return }
            var edited = original
            edited.updatedAtUTC = self.instant(200)
            edited.imageLocalPath = editedName
            edited.memo = "edited during sync"
            try await entryRepository?.upsert(edited)
        }

        let status = await makeService().synchronize(trigger: .localChange)

        XCTAssertEqual(status.state, .synced)
        XCTAssertEqual(remoteStore.savedEntries.map(\.updatedAtUTC), [instant(100), instant(200)])
        XCTAssertEqual(remoteStore.savedMedia.map(\.updatedAtUTC), [instant(200)])
        XCTAssertEqual(remoteStore.savedMedia.first?.fileName, editedName)
        let lastMetadataIndex = try XCTUnwrap(remoteStore.events.lastIndex { $0 == "entry:2026-05-25" })
        let mediaIndex = try XCTUnwrap(remoteStore.events.firstIndex { $0 == "media:2026-05-25:image" })
        XCTAssertLessThan(lastMetadataIndex, mediaIndex)
    }

    func testCorruptNewerRemoteImagePreservesGoodLocalMediaAndRetries() async throws {
        let localName = "healthy-local.jpg"
        let localData = validJPEGData(color: .purple)
        try localData.write(to: entriesDirectory.appending(path: localName))
        try await seed(entries: [localEntry("2026-05-21", updatedAtUTC: instant(100), imageLocalPath: localName)])
        let corruptURL = remoteAssetsDirectory.appending(path: "corrupt.jpg")
        try Data([0, 1, 2]).write(to: corruptURL)
        remoteStore.remoteEntries = [cloudRecord("2026-05-21", updatedAtUTC: instant(600), memo: "new")]
        remoteStore.remoteMedia = [media("2026-05-21", role: .image, updatedAtUTC: instant(600), url: corruptURL)]

        let firstStatus = await makeService().synchronize(trigger: .manual)
        let preservedValue = try await entryRepository.fetchEntry(for: "2026-05-21")
        let preserved = try XCTUnwrap(preservedValue)
        XCTAssertEqual(firstStatus.state, .incomplete)
        XCTAssertEqual(preserved.updatedAtUTC, instant(100))
        XCTAssertEqual(preserved.imageLocalPath, localName)
        XCTAssertEqual(try Data(contentsOf: entriesDirectory.appending(path: localName)), localData)

        let repairedURL = remoteAssetsDirectory.appending(path: "repaired.jpg")
        try validJPEGData(color: .cyan).write(to: repairedURL)
        remoteStore.remoteMedia = [media("2026-05-21", role: .image, updatedAtUTC: instant(600), url: repairedURL)]
        let secondStatus = await makeService().synchronize(trigger: .launch)
        let repairedValue = try await entryRepository.fetchEntry(for: "2026-05-21")
        let repaired = try XCTUnwrap(repairedValue)
        XCTAssertEqual(secondStatus.state, .incomplete) // thumbnail fallback still needs its cloud record
        XCTAssertEqual(repaired.updatedAtUTC, instant(600))
        XCTAssertNotEqual(repaired.imageLocalPath, localName)
    }

    func testNewerRemoteImageWithoutThumbnailDoesNotRetainStaleThumbnail() async throws {
        let localImage = "old-image.jpg"
        let localThumbnail = "old-thumbnail.jpg"
        try validJPEGData(color: .black).write(to: entriesDirectory.appending(path: localImage))
        try validJPEGData(color: .gray).write(to: entriesDirectory.appending(path: localThumbnail))
        var entry = localEntry("2026-05-22", updatedAtUTC: instant(100), imageLocalPath: localImage)
        entry.thumbnailLocalPath = localThumbnail
        try await seed(entries: [entry])
        let remoteURL = remoteAssetsDirectory.appending(path: "new-image.jpg")
        try validJPEGData(color: .white).write(to: remoteURL)
        remoteStore.remoteEntries = [cloudRecord("2026-05-22", updatedAtUTC: instant(700), memo: "new")]
        remoteStore.remoteMedia = [media("2026-05-22", role: .image, updatedAtUTC: instant(700), url: remoteURL)]

        let status = await makeService().synchronize(trigger: .manual)
        let restoredValue = try await entryRepository.fetchEntry(for: "2026-05-22")
        let restored = try XCTUnwrap(restoredValue)
        XCTAssertEqual(status.state, .incomplete)
        XCTAssertEqual(restored.thumbnailLocalPath, restored.imageLocalPath)
        XCTAssertNotEqual(restored.thumbnailLocalPath, localThumbnail)
    }

    func testCompareAndSetRejectsConcurrentNewerLocalEdit() async throws {
        let original = localEntry("2026-05-23", updatedAtUTC: instant(100), imageLocalPath: "one.jpg")
        try await seed(entries: [original])
        var newer = original
        newer.updatedAtUTC = instant(800)
        newer.memo = "newer local"
        try await entryRepository.upsert(newer)
        var staleRemote = original
        staleRemote.memo = "stale remote"

        let didReplace = try await entryRepository.upsert(staleRemote, replacing: original)

        XCTAssertFalse(didReplace)
        let persistedEntry = try await entryRepository.fetchEntry(for: "2026-05-23")
        XCTAssertEqual(persistedEntry?.memo, "newer local")
    }

    func testCloudSaveOrderingRejectsOlderValuesAndProtectsTombstones() {
        let active = cloudRecord("2026-05-24", updatedAtUTC: instant(900))
        let newer = cloudRecord("2026-05-24", updatedAtUTC: instant(901))
        let tombstone = cloudRecord("2026-05-24", updatedAtUTC: instant(900), isDeleted: true)
        XCTAssertFalse(CloudKitRemoteStore.shouldSave(entry: active, over: newer))
        XCTAssertTrue(CloudKitRemoteStore.shouldSave(entry: tombstone, over: active))
        XCTAssertFalse(CloudKitRemoteStore.shouldSave(entry: active, over: tombstone))

        let olderMedia = CloudSyncMediaAsset(localDateString: "2026-05-24", role: .image, fileName: "a.jpg", updatedAtUTC: instant(1), assetFileURL: nil)
        let newerMedia = CloudSyncMediaAsset(localDateString: "2026-05-24", role: .image, fileName: "b.jpg", updatedAtUTC: instant(2), assetFileURL: nil)
        XCTAssertFalse(CloudKitRemoteStore.shouldSave(media: olderMedia, over: newerMedia))
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
        XCTAssertEqual(remoteStoreFactoryCallCount, 0)
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
        XCTAssertEqual(remoteStoreFactoryCallCount, 0)
        XCTAssertEqual(remoteStore.accountStateCallCount, 0)
        XCTAssertTrue(remoteStore.savedEntries.isEmpty)
        XCTAssertTrue(remoteStore.savedMedia.isEmpty)

        if case .disabled = status.state {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected disabled status, got \(status.state)")
        }
    }

    func testLatestStatusDoesNotInstantiateRemoteStoreForPolicyRendering() async {
        let service = makeService()
        let status = await service.latestStatus()

        XCTAssertEqual(status, .idle)
        XCTAssertEqual(remoteStoreFactoryCallCount, 0)
        XCTAssertEqual(remoteStore.accountStateCallCount, 0)
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
            remoteStoreFactory: {
                self.remoteStoreFactoryCallCount += 1
                return self.remoteStore
            },
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

    private func validJPEGData(color: UIColor) -> Data {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4)).image { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        }
        return image.jpegData(compressionQuality: 0.9) ?? Data()
    }

    private func media(_ date: String, role: CloudSyncMediaRole, updatedAtUTC: Date, url: URL?) -> CloudSyncMediaAsset {
        CloudSyncMediaAsset(localDateString: date, role: role, fileName: url?.lastPathComponent ?? "missing.jpg", updatedAtUTC: updatedAtUTC, assetFileURL: url)
    }
}

private final class FakeCloudSyncRemoteStore: CloudSyncRemoteStore {
    var accountStateValue: CloudSyncAccountState = .available
    var remoteEntries: [CloudSyncEntryRecord] = []
    var remoteMedia: [CloudSyncMediaAsset] = []
    private(set) var accountStateCallCount = 0
    private(set) var savedEntries: [CloudSyncEntryRecord] = []
    private(set) var savedMedia: [CloudSyncMediaAsset] = []
    var mediaSaveFailuresRemaining = 0
    private(set) var events: [String] = []
    var onSaveEntry: ((CloudSyncEntryRecord) async throws -> Void)?

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
        events.append("entry:\(entry.localDateString)")
        try await onSaveEntry?(entry)
        savedEntries.append(entry)
        remoteEntries.removeAll { $0.localDateString == entry.localDateString }
        remoteEntries.append(entry)
    }

    func save(media: CloudSyncMediaAsset) async throws {
        events.append("media:\(media.localDateString):\(media.role.rawValue)")
        if mediaSaveFailuresRemaining > 0 {
            mediaSaveFailuresRemaining -= 1
            throw URLError(.networkConnectionLost)
        }
        savedMedia.append(media)
        remoteMedia.removeAll { $0.localDateString == media.localDateString && $0.role == media.role }
        remoteMedia.append(media)
    }
}
