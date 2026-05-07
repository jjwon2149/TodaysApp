import Foundation

struct MissionService {
    private let repository: MissionRepository

    init(repository: MissionRepository = MissionRepository()) {
        self.repository = repository
    }

    func mission(for localDateString: String) async throws -> DailyMission {
        if let mission = try await repository.fetchMission(for: localDateString) {
            return mission
        }

        let mission = makeMission(for: localDateString)
        try await repository.upsert(mission)
        return mission
    }

    func completeMission(for localDateString: String) async throws -> DailyMission {
        var mission = try await mission(for: localDateString)

        if mission.isCompleted == false {
            mission.completedAtUTC = .now
            try await repository.upsert(mission)
        }

        return mission
    }

    private func makeMission(for localDateString: String) -> DailyMission {
        let template = Self.template(for: localDateString)

        return DailyMission(
            id: "\(localDateString)-\(template.id)",
            localDateString: localDateString,
            templateID: template.id,
            title: template.titleKey,
            prompt: template.promptKey,
            category: template.categoryKey,
            symbolName: template.symbolName
        )
    }

    private static func template(for localDateString: String) -> MissionTemplate {
        let checksum = localDateString.unicodeScalars.reduce(0) { partialResult, scalar in
            partialResult + Int(scalar.value)
        }
        return missionTemplates[checksum % missionTemplates.count]
    }
}

private struct MissionTemplate {
    let id: String
    let titleKey: String
    let promptKey: String
    let categoryKey: String
    let symbolName: String
}

private let missionTemplates: [MissionTemplate] = [
    .init(
        id: "today-scene",
        titleKey: "mission.today_scene.title",
        promptKey: "mission.today_scene.prompt",
        categoryKey: "mission.category.record",
        symbolName: "camera.aperture"
    ),
    .init(
        id: "favorite-color",
        titleKey: "mission.favorite_color.title",
        promptKey: "mission.favorite_color.prompt",
        categoryKey: "mission.category.observation",
        symbolName: "paintpalette.fill"
    ),
    .init(
        id: "place-stayed",
        titleKey: "mission.place_stayed.title",
        promptKey: "mission.place_stayed.prompt",
        categoryKey: "mission.category.place",
        symbolName: "mappin.and.ellipse"
    ),
    .init(
        id: "small-routine",
        titleKey: "mission.small_routine.title",
        promptKey: "mission.small_routine.prompt",
        categoryKey: "mission.category.habit",
        symbolName: "repeat.circle.fill"
    ),
    .init(
        id: "quiet-moment",
        titleKey: "mission.quiet_moment.title",
        promptKey: "mission.quiet_moment.prompt",
        categoryKey: "mission.category.sense",
        symbolName: "moon.stars.fill"
    )
]
