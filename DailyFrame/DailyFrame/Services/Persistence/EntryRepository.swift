import Foundation

struct EntryRepository {
    let store: PersistenceStore

    init(store: PersistenceStore = .shared) {
        self.store = store
    }

    func fetchEntry(for localDateString: String) async throws -> DailyPhotoEntry? {
        try await store.load().entries.first {
            $0.localDateString == localDateString && $0.isDeleted == false
        }
    }

    func fetchAllActiveEntries() async throws -> [DailyPhotoEntry] {
        try await store.load().entries
            .filter { $0.isDeleted == false }
            .sorted { $0.localDateString < $1.localDateString }
    }

    func fetchActiveMediaLocalPaths() async throws -> Set<String> {
        let entries = try await fetchAllActiveEntries()
        return Set(entries.flatMap { entry in
            [entry.imageLocalPath, entry.thumbnailLocalPath].compactMap { $0 }
        })
    }

    func fetchEntries(inMonthPrefix monthPrefix: String) async throws -> [DailyPhotoEntry] {
        try await store.load().entries
            .filter { $0.localDateString.hasPrefix(monthPrefix) && $0.isDeleted == false }
            .sorted { $0.localDateString < $1.localDateString }
    }

    func upsert(_ entry: DailyPhotoEntry) async throws {
        try await store.update { snapshot in
            if let index = snapshot.entries.firstIndex(where: { $0.localDateString == entry.localDateString }) {
                snapshot.entries[index] = entry
            } else {
                snapshot.entries.append(entry)
            }
        }
    }

    /// Replaces an entry only while its persisted value still matches the value
    /// observed by the caller. This keeps a sync result from overwriting an edit
    /// or tombstone that was written while remote work was in flight.
    func upsert(
        _ entry: DailyPhotoEntry,
        replacing expectedEntry: DailyPhotoEntry?
    ) async throws -> Bool {
        var didUpdate = false

        try await store.update { snapshot in
            let index = snapshot.entries.firstIndex { $0.localDateString == entry.localDateString }

            switch (index, expectedEntry) {
            case (.none, .none):
                snapshot.entries.append(entry)
                didUpdate = true
            case (.some(let index), .some(let expectedEntry))
                where Self.entriesMatch(snapshot.entries[index], expectedEntry):
                snapshot.entries[index] = entry
                didUpdate = true
            default:
                break
            }
        }

        return didUpdate
    }

    func setThumbnailLocalPath(
        _ thumbnailLocalPath: String,
        for localDateString: String,
        matchingImageLocalPath imageLocalPath: String
    ) async throws -> Bool {
        var didUpdate = false

        try await store.update { snapshot in
            guard let index = snapshot.entries.firstIndex(where: { $0.localDateString == localDateString }) else {
                return
            }

            guard snapshot.entries[index].isDeleted == false,
                  snapshot.entries[index].thumbnailLocalPath == nil,
                  snapshot.entries[index].imageLocalPath == imageLocalPath
            else {
                return
            }

            snapshot.entries[index].thumbnailLocalPath = thumbnailLocalPath
            didUpdate = true
        }

        return didUpdate
    }

    func softDelete(localDateString: String) async throws {
        try await store.update { snapshot in
            guard let index = snapshot.entries.firstIndex(where: { $0.localDateString == localDateString }) else {
                return
            }

            snapshot.entries[index].isDeleted = true
            snapshot.entries[index].updatedAtUTC = .now
        }
    }

    private static func entriesMatch(_ lhs: DailyPhotoEntry, _ rhs: DailyPhotoEntry) -> Bool {
        lhs.id == rhs.id
            && lhs.localDateString == rhs.localDateString
            && lhs.createdAtUTC == rhs.createdAtUTC
            && lhs.updatedAtUTC == rhs.updatedAtUTC
            && lhs.timezoneIdentifier == rhs.timezoneIdentifier
            && lhs.timezoneOffsetMinutes == rhs.timezoneOffsetMinutes
            && lhs.imageLocalPath == rhs.imageLocalPath
            && lhs.thumbnailLocalPath == rhs.thumbnailLocalPath
            && lhs.memo == rhs.memo
            && lhs.moodCode == rhs.moodCode
            && lhs.missionId == rhs.missionId
            && lhs.missionCompleted == rhs.missionCompleted
            && lhs.sourceType == rhs.sourceType
            && lhs.isDeleted == rhs.isDeleted
    }
}
