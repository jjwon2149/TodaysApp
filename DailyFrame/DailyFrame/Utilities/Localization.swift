import Foundation

enum L10n {
    static func string(_ key: String) -> String {
        String(localized: String.LocalizationValue(key))
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: string(key), locale: .current, arguments: arguments)
    }
}

struct MoodOption: Identifiable {
    let id: String
    let localizationKey: String

    var title: String {
        L10n.string(localizationKey)
    }
}

enum MoodLocalization {
    static let options: [MoodOption] = [
        .init(id: "좋음", localizationKey: "editor.mood.good"),
        .init(id: "평온", localizationKey: "editor.mood.calm"),
        .init(id: "피곤", localizationKey: "editor.mood.tired"),
        .init(id: "설렘", localizationKey: "editor.mood.excited"),
        .init(id: "복잡", localizationKey: "editor.mood.mixed"),
        .init(id: "그저 그럼", localizationKey: "editor.mood.neutral")
    ]

    static func displayName(for code: String?) -> String {
        guard let code else {
            return L10n.string("entry.detail.no_record")
        }

        return options.first { $0.id == code }?.title ?? code
    }
}
