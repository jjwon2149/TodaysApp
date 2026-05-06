import Foundation

struct StreakStateRepository {
    let store: PersistenceStore

    init(store: PersistenceStore = .shared) {
        self.store = store
    }

    func fetchPrimaryState() async throws -> StreakState {
        try await store.load().streakState
    }

    func save(_ state: StreakState) async throws {
        try await store.update { snapshot in
            snapshot.streakState = state
        }
    }
}
