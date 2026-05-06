import Foundation

struct MissionRepository {
    let store: PersistenceStore

    init(store: PersistenceStore = .shared) {
        self.store = store
    }

    func fetchMission(for localDateString: String) async throws -> DailyMission? {
        try await store.load().missionHistory.first {
            $0.localDateString == localDateString
        }
    }

    func fetchAllMissions() async throws -> [DailyMission] {
        try await store.load().missionHistory
            .sorted { $0.localDateString < $1.localDateString }
    }

    func upsert(_ mission: DailyMission) async throws {
        try await store.update { snapshot in
            if let index = snapshot.missionHistory.firstIndex(where: { $0.localDateString == mission.localDateString }) {
                snapshot.missionHistory[index] = mission
            } else {
                snapshot.missionHistory.append(mission)
            }
        }
    }
}
