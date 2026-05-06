import Foundation

struct ImageStorageService {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func makeEntriesDirectoryIfNeeded() throws -> URL {
        let directory = try baseDirectory()

        if fileManager.fileExists(atPath: directory.path) == false {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        return directory
    }

    func saveImageData(_ data: Data, fileName: String) throws -> URL {
        let directory = try makeEntriesDirectoryIfNeeded()
        let fileURL = directory.appending(path: fileName)
        try data.write(to: fileURL, options: [.atomic])
        return fileURL
    }

    func deleteFileIfExists(at path: String) throws {
        guard fileManager.fileExists(atPath: path) else {
            return
        }

        try fileManager.removeItem(atPath: path)
    }

    private func baseDirectory() throws -> URL {
        guard let directory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw CocoaError(.fileNoSuchFile)
        }

        return directory
            .appending(path: "DailyFrame")
            .appending(path: "Entries")
    }
}
