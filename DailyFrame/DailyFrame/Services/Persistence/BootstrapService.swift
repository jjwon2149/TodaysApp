import Foundation

struct BootstrapService {
    let store: PersistenceStore

    init(store: PersistenceStore = .shared) {
        self.store = store
    }

    func seedDefaultsIfNeeded() async throws {
        _ = try await store.load()
    }
}
