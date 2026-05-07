import Foundation

struct DailyMission: Codable, Identifiable {
    var id: String
    var localDateString: String
    var templateID: String
    var title: String
    var prompt: String
    var category: String
    var symbolName: String
    var createdAtUTC: Date
    var completedAtUTC: Date?

    var isCompleted: Bool {
        completedAtUTC != nil
    }

    var localizedTitle: String {
        Self.localizedValue(for: templateID, kind: .title) ?? title
    }

    var localizedPrompt: String {
        Self.localizedValue(for: templateID, kind: .prompt) ?? prompt
    }

    var localizedCategory: String {
        Self.localizedValue(for: templateID, kind: .category) ?? category
    }

    init(
        id: String,
        localDateString: String,
        templateID: String,
        title: String,
        prompt: String,
        category: String,
        symbolName: String,
        createdAtUTC: Date = .now,
        completedAtUTC: Date? = nil
    ) {
        self.id = id
        self.localDateString = localDateString
        self.templateID = templateID
        self.title = title
        self.prompt = prompt
        self.category = category
        self.symbolName = symbolName
        self.createdAtUTC = createdAtUTC
        self.completedAtUTC = completedAtUTC
    }

    private enum LocalizedKind {
        case title
        case prompt
        case category
    }

    private static func localizedValue(for templateID: String, kind: LocalizedKind) -> String? {
        let prefix: String
        let categoryKey: String

        switch templateID {
        case "today-scene":
            prefix = "mission.today_scene"
            categoryKey = "mission.category.record"
        case "favorite-color":
            prefix = "mission.favorite_color"
            categoryKey = "mission.category.observation"
        case "place-stayed":
            prefix = "mission.place_stayed"
            categoryKey = "mission.category.place"
        case "small-routine":
            prefix = "mission.small_routine"
            categoryKey = "mission.category.habit"
        case "quiet-moment":
            prefix = "mission.quiet_moment"
            categoryKey = "mission.category.sense"
        default:
            return nil
        }

        switch kind {
        case .title:
            return L10n.string("\(prefix).title")
        case .prompt:
            return L10n.string("\(prefix).prompt")
        case .category:
            return L10n.string(categoryKey)
        }
    }
}
