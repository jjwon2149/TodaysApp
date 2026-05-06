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
}
