import Foundation

actor PersistenceStore {
    static let shared = PersistenceStore()

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let fileManager = FileManager.default
    private let baseDirectoryURL: URL?

    init(baseDirectoryURL: URL? = nil) {
        self.baseDirectoryURL = baseDirectoryURL
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    func load() throws -> AppStateSnapshot {
        let fileURL = try stateFileURL()

        guard fileManager.fileExists(atPath: fileURL.path) else {
            let initial = AppStateSnapshot.initial
            try save(initial)
            return initial
        }

        let data = try Data(contentsOf: fileURL)
        return try decoder.decode(AppStateSnapshot.self, from: data)
    }

    func save(_ snapshot: AppStateSnapshot) throws {
        let directory = try baseDirectory()

        if fileManager.fileExists(atPath: directory.path) == false {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        let data = try encoder.encode(snapshot)
        try data.write(to: try stateFileURL(), options: [.atomic])
    }

    func update(_ mutate: (inout AppStateSnapshot) -> Void) throws {
        var snapshot = try load()
        mutate(&snapshot)
        try save(snapshot)
    }

    private func stateFileURL() throws -> URL {
        try baseDirectory().appending(path: "app-state.json")
    }

    private func baseDirectory() throws -> URL {
        if let baseDirectoryURL {
            return baseDirectoryURL
        }

        guard let directory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw CocoaError(.fileNoSuchFile)
        }

        return directory.appending(path: "DailyFrame")
    }
}
