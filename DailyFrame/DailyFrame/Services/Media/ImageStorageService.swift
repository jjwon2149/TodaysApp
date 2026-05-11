import Foundation
import UIKit

struct ImageStorageService {
    enum Policy {
        static let storedImageMaxPixelDimension: CGFloat = 2_048
        static let storedImageJPEGQuality: CGFloat = 0.82
        static let thumbnailPixelSize: CGFloat = 480
        static let thumbnailJPEGQuality: CGFloat = 0.78
    }

    struct StoredEntryImage {
        let imageURL: URL
        let thumbnailURL: URL
    }

    struct EntryImageFileNames {
        let imageFileName: String
        let thumbnailFileName: String
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
    private let baseDirectoryURL: URL?

    init(fileManager: FileManager = .default, baseDirectoryURL: URL? = nil) {
        self.fileManager = fileManager
        self.baseDirectoryURL = baseDirectoryURL
    }

    func makeEntriesDirectoryIfNeeded() throws -> URL {
        let directory = try baseDirectory()

        if fileManager.fileExists(atPath: directory.path) == false {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        return directory
    }

    func makeEntryImageFileNames(localDateString: String, id: UUID = UUID()) -> EntryImageFileNames {
        let imageFileName = "\(localDateString)-\(id.uuidString).jpg"
        return EntryImageFileNames(
            imageFileName: imageFileName,
            thumbnailFileName: makeThumbnailFileName(localDateString: localDateString, id: id)
        )
    }

    func makeThumbnailFileName(localDateString: String, id: UUID = UUID()) -> String {
        "\(localDateString)-\(id.uuidString)-thumbnail.jpg"
    }

    func saveEntryImageData(_ data: Data, imageFileName: String, thumbnailFileName: String) throws -> StoredEntryImage {
        try validateFileName(imageFileName)
        try validateFileName(thumbnailFileName)

        guard let image = UIImage(data: data) else {
            throw CocoaError(.fileReadCorruptFile)
        }

        let storedImageData = try makeStoredJPEGData(from: image)
        let thumbnailData = try makeThumbnailJPEGData(from: image)
        let imageURL = try saveImageData(storedImageData, fileName: imageFileName)

        do {
            let thumbnailURL = try saveImageData(thumbnailData, fileName: thumbnailFileName)
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

        try validateFileName(fileName)
        return try saveImageData(makeThumbnailJPEGData(from: image), fileName: fileName)
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
                fileName: makeThumbnailFileName(localDateString: entry.localDateString)
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

    private func makeStoredJPEGData(from image: UIImage) throws -> Data {
        guard image.size.width > 0, image.size.height > 0 else {
            throw CocoaError(.fileReadCorruptFile)
        }

        let longestSide = max(image.size.width, image.size.height)
        let scale = min(1, Policy.storedImageMaxPixelDimension / longestSide)
        let targetSize = CGSize(
            width: max(1, floor(image.size.width * scale)),
            height: max(1, floor(image.size.height * scale))
        )

        let renderedImage = renderImage(
            image,
            canvasSize: targetSize,
            drawRect: CGRect(origin: .zero, size: targetSize)
        )

        guard let data = renderedImage.jpegData(compressionQuality: Policy.storedImageJPEGQuality) else {
            throw CocoaError(.fileWriteUnknown)
        }

        return data
    }

    private func makeThumbnailJPEGData(from image: UIImage) throws -> Data {
        guard image.size.width > 0, image.size.height > 0 else {
            throw CocoaError(.fileReadCorruptFile)
        }

        let targetSize = CGSize(width: Policy.thumbnailPixelSize, height: Policy.thumbnailPixelSize)
        let scale = max(targetSize.width / image.size.width, targetSize.height / image.size.height)
        let scaledSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let origin = CGPoint(
            x: (targetSize.width - scaledSize.width) / 2,
            y: (targetSize.height - scaledSize.height) / 2
        )

        let thumbnail = renderImage(
            image,
            canvasSize: targetSize,
            drawRect: CGRect(origin: origin, size: scaledSize)
        )

        guard let data = thumbnail.jpegData(compressionQuality: Policy.thumbnailJPEGQuality) else {
            throw CocoaError(.fileWriteUnknown)
        }

        return data
    }

    private func renderImage(_ image: UIImage, canvasSize: CGSize, drawRect: CGRect) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: canvasSize))
            image.draw(in: drawRect)
        }
    }

    private func saveImageData(_ data: Data, fileName: String) throws -> URL {
        let directory = try makeEntriesDirectoryIfNeeded()
        let fileURL = directory.appendingPathComponent(fileName, isDirectory: false)
        try data.write(to: fileURL, options: [.atomic])
        return fileURL
    }

    private func validateFileName(_ fileName: String) throws {
        guard fileName.isEmpty == false,
              fileName == URL(fileURLWithPath: fileName).lastPathComponent,
              fileName.hasSuffix(".jpg")
        else {
            throw CocoaError(.fileWriteInvalidFileName)
        }
    }

    private func standardizedPath(_ path: String) -> String {
        URL(fileURLWithPath: path).standardizedFileURL.path
    }

    private func baseDirectory() throws -> URL {
        if let baseDirectoryURL {
            return baseDirectoryURL
        }

        guard let directory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw CocoaError(.fileNoSuchFile)
        }

        return directory
            .appending(path: "DailyFrame")
            .appending(path: "Entries")
    }
}
