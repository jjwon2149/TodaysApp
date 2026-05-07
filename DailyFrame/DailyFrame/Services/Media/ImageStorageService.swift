import Foundation
import UIKit

struct ImageStorageService {
    struct StoredEntryImage {
        let imageURL: URL
        let thumbnailURL: URL
    }

    struct MaintenanceResult {
        private(set) var backfilledThumbnailCount = 0
        private(set) var deletedOrphanFileCount = 0
        private(set) var failureCount = 0

        fileprivate mutating func recordBackfilledThumbnail() {
            backfilledThumbnailCount += 1
        }

        fileprivate mutating func recordDeletedOrphanFile() {
            deletedOrphanFileCount += 1
        }

        fileprivate mutating func recordFailure() {
            failureCount += 1
        }
    }

    private let fileManager: FileManager
    private let thumbnailPixelSize: CGFloat = 360

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

    func saveEntryImageData(_ data: Data, imageFileName: String, thumbnailFileName: String) throws -> StoredEntryImage {
        let imageURL = try saveImageData(data, fileName: imageFileName)

        do {
            let thumbnailURL = try saveThumbnailData(from: data, fileName: thumbnailFileName)
            return StoredEntryImage(imageURL: imageURL, thumbnailURL: thumbnailURL)
        } catch {
            try? deleteFileIfExists(at: imageURL.path)
            throw error
        }
    }

    func saveThumbnail(forImageAt imagePath: String, fileName: String) throws -> URL {
        guard let image = UIImage(contentsOfFile: imagePath) else {
            throw CocoaError(.fileReadCorruptFile)
        }

        return try saveThumbnailImage(image, fileName: fileName)
    }

    func deleteFileIfExists(at path: String) throws {
        guard fileManager.fileExists(atPath: path) else {
            return
        }

        try fileManager.removeItem(atPath: path)
    }

    @discardableResult
    func performLaunchMaintenance(entryRepository: EntryRepository = EntryRepository()) async -> MaintenanceResult {
        var result = MaintenanceResult()

        do {
            let entries = try await entryRepository.fetchAllActiveEntries()

            for entry in entries where entry.thumbnailLocalPath == nil {
                await backfillThumbnailIfNeeded(for: entry, entryRepository: entryRepository, result: &result)
            }

            let referencedPaths = try await entryRepository.fetchActiveMediaLocalPaths()
            deleteOrphanFiles(referencedPaths: referencedPaths, result: &result)
        } catch {
            result.recordFailure()
        }

        return result
    }

    private func backfillThumbnailIfNeeded(
        for entry: DailyPhotoEntry,
        entryRepository: EntryRepository,
        result: inout MaintenanceResult
    ) async {
        do {
            let thumbnailURL = try saveThumbnail(
                forImageAt: entry.imageLocalPath,
                fileName: makeThumbnailFileName(for: entry)
            )
            let didUpdate = try await entryRepository.setThumbnailLocalPath(
                thumbnailURL.path,
                for: entry.localDateString,
                matchingImageLocalPath: entry.imageLocalPath
            )

            if didUpdate {
                result.recordBackfilledThumbnail()
            } else {
                try? deleteFileIfExists(at: thumbnailURL.path)
            }
        } catch {
            result.recordFailure()
        }
    }

    private func deleteOrphanFiles(referencedPaths: Set<String>, result: inout MaintenanceResult) {
        let referencedPaths = Set(referencedPaths.map(standardizedPath))

        do {
            let directory = try baseDirectory()

            guard fileManager.fileExists(atPath: directory.path) else {
                return
            }

            let fileURLs = try fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )

            for fileURL in fileURLs {
                do {
                    let resourceValues = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
                    guard resourceValues.isRegularFile == true else {
                        continue
                    }

                    guard referencedPaths.contains(fileURL.standardizedFileURL.path) == false else {
                        continue
                    }

                    try fileManager.removeItem(at: fileURL)
                    result.recordDeletedOrphanFile()
                } catch {
                    result.recordFailure()
                }
            }
        } catch {
            result.recordFailure()
        }
    }

    private func saveThumbnailData(from data: Data, fileName: String) throws -> URL {
        guard let image = UIImage(data: data) else {
            throw CocoaError(.fileReadCorruptFile)
        }

        return try saveThumbnailImage(image, fileName: fileName)
    }

    private func saveThumbnailImage(_ image: UIImage, fileName: String) throws -> URL {
        guard image.size.width > 0, image.size.height > 0 else {
            throw CocoaError(.fileReadCorruptFile)
        }

        let targetSize = CGSize(width: thumbnailPixelSize, height: thumbnailPixelSize)
        let scale = max(targetSize.width / image.size.width, targetSize.height / image.size.height)
        let scaledSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let origin = CGPoint(
            x: (targetSize.width - scaledSize.width) / 2,
            y: (targetSize.height - scaledSize.height) / 2
        )

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let thumbnail = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: targetSize))
            image.draw(in: CGRect(origin: origin, size: scaledSize))
        }

        guard let data = thumbnail.jpegData(compressionQuality: 0.78) else {
            throw CocoaError(.fileWriteUnknown)
        }

        return try saveImageData(data, fileName: fileName)
    }

    private func makeThumbnailFileName(for entry: DailyPhotoEntry) -> String {
        "\(entry.localDateString)-\(UUID().uuidString)-thumbnail.jpg"
    }

    private func standardizedPath(_ path: String) -> String {
        URL(fileURLWithPath: path).standardizedFileURL.path
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
