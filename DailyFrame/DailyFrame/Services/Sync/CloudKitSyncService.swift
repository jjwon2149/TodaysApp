import Foundation
import UIKit

actor CloudKitSyncService {
    static let shared = CloudKitSyncService()

    private struct SyncSummary {
        var uploadedEntryCount = 0
        var downloadedEntryCount = 0
        var uploadedMediaCount = 0
        var downloadedMediaCount = 0
        var skippedMediaCount = 0
    }

    private let remoteStoreFactory: () -> CloudSyncRemoteStore
    private let entryRepository: EntryRepository
    private let imageStorageService: ImageStorageService
    private let appSettingsRepository: AppSettingsRepository
    private let nowProvider: () -> Date
    private var cachedRemoteStore: CloudSyncRemoteStore?
    private var status: CloudSyncStatus = .idle
    private var isSyncing = false

    init(
        remoteStoreFactory: @escaping () -> CloudSyncRemoteStore = { CloudKitRemoteStore() },
        entryRepository: EntryRepository = EntryRepository(),
        imageStorageService: ImageStorageService = ImageStorageService(),
        appSettingsRepository: AppSettingsRepository = AppSettingsRepository(),
        nowProvider: @escaping () -> Date = { .now }
    ) {
        self.remoteStoreFactory = remoteStoreFactory
        self.entryRepository = entryRepository
        self.imageStorageService = imageStorageService
        self.appSettingsRepository = appSettingsRepository
        self.nowProvider = nowProvider
    }

    func latestStatus() -> CloudSyncStatus {
        status
    }

    @discardableResult
    func synchronize(trigger: CloudSyncRunTrigger) async -> CloudSyncStatus {
        guard isSyncing == false else {
            return status
        }

        isSyncing = true
        defer { isSyncing = false }

        do {
            let settings = try await appSettingsRepository.fetchSettings()
            let syncPolicy = settings.effectiveICloudSyncPolicy

            guard syncPolicy.allowsSync else {
                status = CloudSyncStatus(
                    state: syncPolicy == .disabled ? .disabled : .notSetUp,
                    lastSyncedAtUTC: status.lastSyncedAtUTC,
                    uploadedEntryCount: 0,
                    downloadedEntryCount: 0,
                    uploadedMediaCount: 0,
                    downloadedMediaCount: 0,
                    skippedMediaCount: 0
                )
                return status
            }

            status = .syncing(previous: status)
            let remoteStore = remoteStoreForAllowedSync()

            let accountState = try await remoteStore.accountState()

            guard case .available = accountState else {
                let reason: CloudSyncUnavailableReason
                if case .unavailable(let unavailableReason) = accountState {
                    reason = unavailableReason
                } else {
                    reason = .unknown
                }

                status = CloudSyncStatus(
                    state: .unavailable(reason),
                    lastSyncedAtUTC: status.lastSyncedAtUTC,
                    uploadedEntryCount: 0,
                    downloadedEntryCount: 0,
                    uploadedMediaCount: 0,
                    downloadedMediaCount: 0,
                    skippedMediaCount: 0
                )
                return status
            }

            let remoteEntries = try await remoteStore.fetchEntries()
            let remoteMedia = try await remoteStore.fetchMedia()
            let summary = try await merge(
                remoteStore: remoteStore,
                remoteEntries: remoteEntries,
                remoteMedia: remoteMedia
            )

            let completedFully = summary.skippedMediaCount == 0
            status = CloudSyncStatus(
                state: completedFully ? .synced : .incomplete,
                lastSyncedAtUTC: completedFully ? nowProvider() : status.lastSyncedAtUTC,
                uploadedEntryCount: summary.uploadedEntryCount,
                downloadedEntryCount: summary.downloadedEntryCount,
                uploadedMediaCount: summary.uploadedMediaCount,
                downloadedMediaCount: summary.downloadedMediaCount,
                skippedMediaCount: summary.skippedMediaCount
            )
        } catch {
            status = CloudSyncStatus(
                state: .failed(error.localizedDescription),
                lastSyncedAtUTC: status.lastSyncedAtUTC,
                uploadedEntryCount: 0,
                downloadedEntryCount: 0,
                uploadedMediaCount: 0,
                downloadedMediaCount: 0,
                skippedMediaCount: 0
            )
        }

        return status
    }

    private func remoteStoreForAllowedSync() -> CloudSyncRemoteStore {
        if let cachedRemoteStore {
            return cachedRemoteStore
        }

        let remoteStore = remoteStoreFactory()
        cachedRemoteStore = remoteStore
        return remoteStore
    }

    private func merge(
        remoteStore: CloudSyncRemoteStore,
        remoteEntries: [CloudSyncEntryRecord],
        remoteMedia: [CloudSyncMediaAsset]
    ) async throws -> SyncSummary {
        var summary = SyncSummary()
        let remoteEntriesByDate = Dictionary(uniqueKeysWithValues: remoteEntries.map { ($0.localDateString, $0) })
        let remoteMediaByDate = Dictionary(grouping: remoteMedia, by: \.localDateString)
        let localEntriesByDate = try await collapsedLocalEntriesByDate()
        let allLocalDateStrings = Set(localEntriesByDate.keys).union(remoteEntriesByDate.keys)
        var uploadedMetadataVersions: [String: Date] = [:]

        // Finish metadata for every entry before attempting any media transfer.
        for localDateString in allLocalDateStrings.sorted() {
            let localEntry = localEntriesByDate[localDateString]
            let remoteEntry = remoteEntriesByDate[localDateString]

            if let localEntry, let remoteEntry {
                if shouldRemoteWin(remoteEntry, over: localEntry) {
                    if remoteEntry.isDeleted {
                        try await applyRemoteEntryMetadata(remoteEntry, expectedEntry: localEntry, summary: &summary)
                    }
                } else if shouldLocalUpload(localEntry, over: remoteEntry) {
                    try await uploadLocalEntryMetadata(localEntry, remoteStore: remoteStore, summary: &summary)
                    uploadedMetadataVersions[localDateString] = localEntry.updatedAtUTC
                }
            } else if let remoteEntry {
                if remoteEntry.isDeleted {
                    try await applyRemoteEntryMetadata(remoteEntry, expectedEntry: nil, summary: &summary)
                }
            } else if let localEntry {
                try await uploadLocalEntryMetadata(localEntry, remoteStore: remoteStore, summary: &summary)
                uploadedMetadataVersions[localDateString] = localEntry.updatedAtUTC
            }
        }

        // Re-read after metadata I/O. A user may have edited or deleted an entry
        // while the remote store was being updated.
        let currentLocalEntriesByDate = try await collapsedLocalEntriesByDate()
        for localDateString in allLocalDateStrings.sorted() {
            let localEntry = currentLocalEntriesByDate[localDateString]
            let remoteEntry = remoteEntriesByDate[localDateString]

            if let remoteEntry,
               remoteEntry.isDeleted == false,
               localEntry == nil || shouldRemoteWin(remoteEntry, over: localEntry!) {
                try await applyRemoteActiveEntry(
                    remoteEntry,
                    expectedEntry: localEntry,
                    mediaRecords: remoteMediaByDate[localDateString] ?? [],
                    summary: &summary
                )
                continue
            }

            guard let localEntry, localEntry.isDeleted == false else {
                continue
            }

            if shouldLocalUpload(localEntry, over: remoteEntry) {
                if uploadedMetadataVersions[localDateString] != localEntry.updatedAtUTC {
                    try await uploadLocalEntryMetadata(localEntry, remoteStore: remoteStore, summary: &summary)
                    uploadedMetadataVersions[localDateString] = localEntry.updatedAtUTC
                }
            } else if let remoteEntry, shouldRemoteWin(remoteEntry, over: localEntry) {
                // A compare-and-set rejection means a concurrent local mutation
                // won. Never reconcile media against stale remote metadata.
                continue
            }

            let recordsByRole = preferredMediaRecordsByRole(remoteMediaByDate[localDateString] ?? [])
            for role in CloudSyncMediaRole.allCases {
                guard let currentEntry = try await entryRepository.fetchEntry(for: localDateString) else {
                    break
                }

                if let remoteEntry, shouldRemoteWin(remoteEntry, over: currentEntry) {
                    break
                }
                if shouldLocalUpload(currentEntry, over: remoteEntry),
                   uploadedMetadataVersions[localDateString] != currentEntry.updatedAtUTC {
                    try await uploadLocalEntryMetadata(currentEntry, remoteStore: remoteStore, summary: &summary)
                    uploadedMetadataVersions[localDateString] = currentEntry.updatedAtUTC
                }
                try await reconcileMedia(
                    role: role,
                    entry: currentEntry,
                    remoteMedia: recordsByRole[role],
                    remoteStore: remoteStore,
                    summary: &summary
                )
            }
        }

        return summary
    }

    private func collapsedLocalEntriesByDate() async throws -> [String: DailyPhotoEntry] {
        try await entryRepository.store.update { snapshot in
            let groupedEntries = Dictionary(grouping: snapshot.entries, by: \.localDateString)
            let collapsedEntries = groupedEntries.values.compactMap { candidates in
                candidates.max { lhs, rhs in
                    isPreferred(rhs, over: lhs)
                }
            }
            if collapsedEntries.count != snapshot.entries.count {
                snapshot.entries = collapsedEntries.sorted { $0.localDateString < $1.localDateString }
            }
        }

        let snapshot = try await entryRepository.store.load()
        let collapsedEntries = snapshot.entries
        return Dictionary(uniqueKeysWithValues: collapsedEntries.map { ($0.localDateString, $0) })
    }

    private func applyRemoteEntryMetadata(
        _ remoteEntry: CloudSyncEntryRecord,
        expectedEntry: DailyPhotoEntry?,
        summary: inout SyncSummary
    ) async throws {
        let mergedEntry = remoteEntry.makeLocalEntry(
            preserving: expectedEntry,
            mediaFileNames: [:]
        )
        if try await entryRepository.upsert(mergedEntry, replacing: expectedEntry) {
            summary.downloadedEntryCount += 1
        } else {
            summary.skippedMediaCount += 1
        }
    }

    private func applyRemoteActiveEntry(
        _ remoteEntry: CloudSyncEntryRecord,
        expectedEntry: DailyPhotoEntry?,
        mediaRecords: [CloudSyncMediaAsset],
        summary: inout SyncSummary
    ) async throws {
        let recordsByRole = preferredMediaRecordsByRole(mediaRecords)
        var downloadedFileNames: [CloudSyncMediaRole: String] = [:]
        var stagedFileNames: [String] = []
        var imageIsComplete = true
        var thumbnailNeedsRecovery = false

        for role in CloudSyncMediaRole.allCases {
            let existingReference = role == .image ? expectedEntry?.imageLocalPath : expectedEntry?.thumbnailLocalPath
            let existingURL = existingReference.flatMap(imageStorageService.resolvedFileURL(for:))
            guard let media = recordsByRole[role] else {
                if role == .image && (expectedEntry == nil || remoteEntry.updatedAtUTC > expectedEntry!.updatedAtUTC) {
                    imageIsComplete = false
                } else if role == .thumbnail, remoteEntry.updatedAtUTC > (expectedEntry?.updatedAtUTC ?? .distantPast) {
                    thumbnailNeedsRecovery = true
                }
                continue
            }

            let needsRemoteVersion = existingURL == nil
                || expectedEntry == nil
                || media.updatedAtUTC > expectedEntry!.updatedAtUTC
                || remoteEntry.updatedAtUTC > expectedEntry!.updatedAtUTC
            guard needsRemoteVersion else {
                continue
            }

            guard media.updatedAtUTC >= remoteEntry.updatedAtUTC else {
                if role == .image {
                    imageIsComplete = false
                } else {
                    thumbnailNeedsRecovery = true
                }
                continue
            }
            guard let savedFileName = stageRemoteMedia(media, role: role) else {
                if role == .image {
                    imageIsComplete = false
                } else {
                    thumbnailNeedsRecovery = true
                }
                continue
            }
            downloadedFileNames[role] = savedFileName
            if savedFileName != existingReference {
                stagedFileNames.append(savedFileName)
            }
        }

        guard imageIsComplete else {
            for fileName in stagedFileNames {
                try? imageStorageService.deleteFileIfExists(at: fileName)
            }
            summary.skippedMediaCount += 1
            return
        }

        if thumbnailNeedsRecovery {
            if let imageFileName = downloadedFileNames[.image] ?? expectedEntry?.imageLocalPath {
                downloadedFileNames[.thumbnail] = imageFileName
            }
            summary.skippedMediaCount += 1
        }

        let mergedEntry = remoteEntry.makeLocalEntry(
            preserving: expectedEntry,
            mediaFileNames: downloadedFileNames
        )
        if try await entryRepository.upsert(mergedEntry, replacing: expectedEntry) {
            summary.downloadedEntryCount += 1
            summary.downloadedMediaCount += stagedFileNames.count
        } else {
            for fileName in stagedFileNames {
                try? imageStorageService.deleteFileIfExists(at: fileName)
            }
            summary.skippedMediaCount += 1
        }
    }

    private func uploadLocalEntryMetadata(
        _ entry: DailyPhotoEntry,
        remoteStore: CloudSyncRemoteStore,
        summary: inout SyncSummary
    ) async throws {
        let record = CloudSyncEntryRecord(entry: entry)
        try await remoteStore.save(entry: record)
        summary.uploadedEntryCount += 1
    }

    private func reconcileMedia(
        role: CloudSyncMediaRole,
        entry: DailyPhotoEntry,
        remoteMedia: CloudSyncMediaAsset?,
        remoteStore: CloudSyncRemoteStore,
        summary: inout SyncSummary
    ) async throws {
        let reference = role == .image ? entry.imageLocalPath : entry.thumbnailLocalPath
        let localAssetURL = reference.flatMap(imageStorageService.resolvedFileURL(for:))

        if let localAssetURL {
            let remoteNeedsUpload = remoteMedia == nil
                || remoteMedia?.assetFileURL == nil
                || entry.updatedAtUTC > (remoteMedia?.updatedAtUTC ?? .distantPast)
            guard remoteNeedsUpload else {
                if let remoteMedia, remoteMedia.updatedAtUTC > entry.updatedAtUTC {
                    await downloadMedia(remoteMedia, role: role, expectedEntry: entry, summary: &summary)
                }
                return
            }

            do {
                try await remoteStore.save(media: CloudSyncMediaAsset(
                    localDateString: entry.localDateString,
                    role: role,
                    fileName: imageStorageService.normalizedMediaReference(for: reference ?? localAssetURL.lastPathComponent),
                    updatedAtUTC: entry.updatedAtUTC,
                    assetFileURL: localAssetURL
                ))
                summary.uploadedMediaCount += 1
            } catch {
                summary.skippedMediaCount += 1
            }
            return
        }

        if let remoteMedia {
            await downloadMedia(remoteMedia, role: role, expectedEntry: entry, summary: &summary)
        } else if role == .image {
            summary.skippedMediaCount += 1
        }
    }

    private func downloadMedia(
        _ media: CloudSyncMediaAsset,
        role: CloudSyncMediaRole,
        expectedEntry: DailyPhotoEntry,
        summary: inout SyncSummary
    ) async {
        guard let savedFileName = stageRemoteMedia(media, role: role) else {
            summary.skippedMediaCount += 1
            return
        }

        do {
            var updatedEntry = expectedEntry
            if role == .image {
                updatedEntry.imageLocalPath = savedFileName
            } else {
                updatedEntry.thumbnailLocalPath = savedFileName
            }

            if try await entryRepository.upsert(updatedEntry, replacing: expectedEntry) {
                summary.downloadedMediaCount += 1
            } else if savedFileName != expectedEntry.imageLocalPath,
                      savedFileName != expectedEntry.thumbnailLocalPath {
                try? imageStorageService.deleteFileIfExists(at: savedFileName)
                summary.skippedMediaCount += 1
            }
        } catch {
            if savedFileName != expectedEntry.imageLocalPath,
               savedFileName != expectedEntry.thumbnailLocalPath {
                try? imageStorageService.deleteFileIfExists(at: savedFileName)
            }
            summary.skippedMediaCount += 1
        }
    }

    private func stageRemoteMedia(
        _ media: CloudSyncMediaAsset,
        role: CloudSyncMediaRole
    ) -> String? {
        let remoteFileName = imageStorageService.normalizedMediaReference(for: media.fileName)
        guard remoteFileName.isEmpty == false, let assetFileURL = media.assetFileURL else {
            return nil
        }

        let baseName = URL(fileURLWithPath: remoteFileName).deletingPathExtension().lastPathComponent
        let stagedFileName = "\(baseName)-sync-\(role.rawValue)-\(UUID().uuidString).jpg"
        guard let savedFileName = try? imageStorageService.saveSyncedMediaFile(
            from: assetFileURL,
            preferredFileName: stagedFileName
        ), let savedURL = imageStorageService.resolvedFileURL(for: savedFileName), UIImage(contentsOfFile: savedURL.path) != nil else {
            try? imageStorageService.deleteFileIfExists(at: stagedFileName)
            return nil
        }
        return savedFileName
    }

    private func preferredMediaRecordsByRole(
        _ records: [CloudSyncMediaAsset]
    ) -> [CloudSyncMediaRole: CloudSyncMediaAsset] {
        records.reduce(into: [:]) { result, record in
            if let current = result[record.role], current.updatedAtUTC > record.updatedAtUTC {
                return
            }
            result[record.role] = record
        }
    }

    private func shouldRemoteWin(_ remoteEntry: CloudSyncEntryRecord, over localEntry: DailyPhotoEntry) -> Bool {
        if remoteEntry.updatedAtUTC > localEntry.updatedAtUTC {
            return true
        }

        return remoteEntry.updatedAtUTC == localEntry.updatedAtUTC
            && remoteEntry.isDeleted
            && localEntry.isDeleted == false
    }

    private func shouldLocalUpload(_ localEntry: DailyPhotoEntry, over remoteEntry: CloudSyncEntryRecord?) -> Bool {
        guard let remoteEntry else {
            return true
        }

        if localEntry.updatedAtUTC > remoteEntry.updatedAtUTC {
            return true
        }

        return localEntry.updatedAtUTC == remoteEntry.updatedAtUTC
            && localEntry.isDeleted
            && remoteEntry.isDeleted == false
    }

    private func isPreferred(_ candidate: DailyPhotoEntry, over current: DailyPhotoEntry) -> Bool {
        if candidate.updatedAtUTC != current.updatedAtUTC {
            return candidate.updatedAtUTC > current.updatedAtUTC
        }

        if candidate.isDeleted != current.isDeleted {
            return candidate.isDeleted
        }

        return candidate.createdAtUTC >= current.createdAtUTC
    }
}
