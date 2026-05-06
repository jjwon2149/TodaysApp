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
            title: template.title,
            prompt: template.prompt,
            category: template.category,
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
    let title: String
    let prompt: String
    let category: String
    let symbolName: String
}

private let missionTemplates: [MissionTemplate] = [
    .init(
        id: "today-scene",
        title: "오늘을 대표하는 장면",
        prompt: "지금 하루를 가장 잘 보여주는 장면을 한 장 남겨보세요.",
        category: "기록",
        symbolName: "camera.aperture"
    ),
    .init(
        id: "favorite-color",
        title: "오늘의 색",
        prompt: "오늘 유난히 눈에 들어온 색이 담긴 장면을 찾아보세요.",
        category: "관찰",
        symbolName: "paintpalette.fill"
    ),
    .init(
        id: "place-stayed",
        title: "오래 머문 곳",
        prompt: "오늘 가장 오래 머문 공간의 분위기를 사진으로 저장해보세요.",
        category: "장소",
        symbolName: "mappin.and.ellipse"
    ),
    .init(
        id: "small-routine",
        title: "작은 루틴",
        prompt: "오늘 반복한 작은 습관이나 손이 간 물건을 찍어보세요.",
        category: "습관",
        symbolName: "repeat.circle.fill"
    ),
    .init(
        id: "quiet-moment",
        title: "조용했던 순간",
        prompt: "잠깐 멈췄던 순간을 한 장으로 남겨보세요.",
        category: "감각",
        symbolName: "moon.stars.fill"
    )
]
