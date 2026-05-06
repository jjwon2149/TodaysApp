import Foundation

struct UserProfileRepository {
    let store: PersistenceStore

    init(store: PersistenceStore = .shared) {
        self.store = store
    }

    func fetchPrimaryProfile() async throws -> UserProfile {
        try await store.load().userProfile
    }

    func save(_ profile: UserProfile) async throws {
        try await store.update { snapshot in
            snapshot.userProfile = profile
        }
    }
}
