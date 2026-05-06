import Foundation

struct AppSettingsRepository {
    let store: PersistenceStore

    init(store: PersistenceStore = .shared) {
        self.store = store
    }

    func fetchSettings() async throws -> AppSettings {
        try await store.load().settings
    }

    func save(_ settings: AppSettings) async throws {
        try await store.update { snapshot in
            snapshot.settings = settings
        }
    }
}
