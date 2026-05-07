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
}
