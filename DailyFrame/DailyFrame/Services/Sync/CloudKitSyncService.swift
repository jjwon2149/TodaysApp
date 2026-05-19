import Foundation

actor CloudKitSyncService {
    static let shared = CloudKitSyncService()

    private struct SyncSummary {
        var uploadedEntryCount = 0
        var downloadedEntryCount = 0
        var uploadedMediaCount = 0
        var downloadedMediaCount = 0
        var skippedMediaCount = 0
    }

    private let remoteStore: CloudSyncRemoteStore
    private let entryRepository: EntryRepository
    private let imageStorageService: ImageStorageService
    private let appSettingsRepository: AppSettingsRepository
    private let nowProvider: () -> Date
    private var status: CloudSyncStatus = .idle
    private var isSyncing = false

    init(
        remoteStore: CloudSyncRemoteStore = CloudKitRemoteStore(),
        entryRepository: EntryRepository = EntryRepository(),
        imageStorageService: ImageStorageService = ImageStorageService(),
        appSettingsRepository: AppSettingsRepository = AppSettingsRepository(),
        nowProvider: @escaping () -> Date = { .now }
    ) {
        self.remoteStore = remoteStore
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
            let summary = try await merge(remoteEntries: remoteEntries, remoteMedia: remoteMedia)

            status = CloudSyncStatus(
                state: .synced,
                lastSyncedAtUTC: nowProvider(),
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

    private func merge(
        remoteEntries: [CloudSyncEntryRecord],
        remoteMedia: [CloudSyncMediaAsset]
    ) async throws -> SyncSummary {
        var summary = SyncSummary()
        let remoteEntriesByDate = Dictionary(uniqueKeysWithValues: remoteEntries.map { ($0.localDateString, $0) })
        let remoteMediaByDate = Dictionary(grouping: remoteMedia, by: \.localDateString)
        var localEntriesByDate = try await collapsedLocalEntriesByDate()
        let allLocalDateStrings = Set(localEntriesByDate.keys).union(remoteEntriesByDate.keys)

        for localDateString in allLocalDateStrings.sorted() {
            let localEntry = localEntriesByDate[localDateString]
            let remoteEntry = remoteEntriesByDate[localDateString]

            if let localEntry, let remoteEntry {
                if shouldRemoteWin(remoteEntry, over: localEntry) {
                    try await applyRemoteEntry(
                        remoteEntry,
                        existingEntry: localEntry,
                        mediaRecords: remoteMediaByDate[localDateString] ?? [],
                        summary: &summary
                    )
                    localEntriesByDate[localDateString] = try await entryRepository.store.load().entries.first {
                        $0.localDateString == localDateString
                    }
                } else if shouldLocalUpload(localEntry, over: remoteEntry) {
                    try await uploadLocalEntry(localEntry, summary: &summary)
                }
            } else if let remoteEntry {
                try await applyRemoteEntry(
                    remoteEntry,
                    existingEntry: nil,
                    mediaRecords: remoteMediaByDate[localDateString] ?? [],
                    summary: &summary
                )
                localEntriesByDate[localDateString] = try await entryRepository.store.load().entries.first {
                    $0.localDateString == localDateString
                }
            } else if let localEntry {
                try await uploadLocalEntry(localEntry, summary: &summary)
            }
        }

        return summary
    }

    private func collapsedLocalEntriesByDate() async throws -> [String: DailyPhotoEntry] {
        let snapshot = try await entryRepository.store.load()
        let groupedEntries = Dictionary(grouping: snapshot.entries, by: \.localDateString)
        let collapsedEntries = groupedEntries.values.compactMap { candidates in
            candidates.max { lhs, rhs in
                isPreferred(rhs, over: lhs)
            }
        }

        if collapsedEntries.count != snapshot.entries.count {
            try await entryRepository.store.update { updatedSnapshot in
                updatedSnapshot.entries = collapsedEntries.sorted { $0.localDateString < $1.localDateString }
            }
        }

        return Dictionary(uniqueKeysWithValues: collapsedEntries.map { ($0.localDateString, $0) })
    }

    private func applyRemoteEntry(
        _ remoteEntry: CloudSyncEntryRecord,
        existingEntry: DailyPhotoEntry?,
        mediaRecords: [CloudSyncMediaAsset],
        summary: inout SyncSummary
    ) async throws {
        var mediaFileNames: [CloudSyncMediaRole: String] = [:]

        for mediaRecord in mediaRecords {
            let fileName = imageStorageService.normalizedMediaReference(for: mediaRecord.fileName)

            guard fileName.isEmpty == false else {
                summary.skippedMediaCount += 1
                continue
            }

            mediaFileNames[mediaRecord.role] = fileName

            guard let assetFileURL = mediaRecord.assetFileURL else {
                summary.skippedMediaCount += 1
                continue
            }

            do {
                mediaFileNames[mediaRecord.role] = try imageStorageService.saveSyncedMediaFile(
                    from: assetFileURL,
                    preferredFileName: fileName
                )
                summary.downloadedMediaCount += 1
            } catch {
                summary.skippedMediaCount += 1
            }
        }

        let mergedEntry = remoteEntry.makeLocalEntry(
            preserving: existingEntry,
            mediaFileNames: mediaFileNames
        )
        try await entryRepository.upsert(mergedEntry)
        summary.downloadedEntryCount += 1
    }

    private func uploadLocalEntry(_ entry: DailyPhotoEntry, summary: inout SyncSummary) async throws {
        let record = CloudSyncEntryRecord(entry: entry)
        try await remoteStore.save(entry: record)
        summary.uploadedEntryCount += 1

        guard entry.isDeleted == false else {
            return
        }

        try await uploadMedia(
            role: .image,
            reference: entry.imageLocalPath,
            updatedAtUTC: entry.updatedAtUTC,
            localDateString: entry.localDateString,
            summary: &summary
        )

        if let thumbnailLocalPath = entry.thumbnailLocalPath {
            try await uploadMedia(
                role: .thumbnail,
                reference: thumbnailLocalPath,
                updatedAtUTC: entry.updatedAtUTC,
                localDateString: entry.localDateString,
                summary: &summary
            )
        }
    }

    private func uploadMedia(
        role: CloudSyncMediaRole,
        reference: String,
        updatedAtUTC: Date,
        localDateString: String,
        summary: inout SyncSummary
    ) async throws {
        let fileName = imageStorageService.normalizedMediaReference(for: reference)

        guard let assetURL = imageStorageService.resolvedFileURL(for: reference) else {
            summary.skippedMediaCount += 1
            return
        }

        try await remoteStore.save(media: CloudSyncMediaAsset(
            localDateString: localDateString,
            role: role,
            fileName: fileName,
            updatedAtUTC: updatedAtUTC,
            assetFileURL: assetURL
        ))
        summary.uploadedMediaCount += 1
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
