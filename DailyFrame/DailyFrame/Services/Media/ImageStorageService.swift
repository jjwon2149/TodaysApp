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
        private(set) var migratedReferenceCount = 0
        private(set) var backfilledThumbnailCount = 0
        private(set) var deletedOrphanFileCount = 0
        private(set) var failureCount = 0

        fileprivate mutating func recordMigratedReference() {
            migratedReferenceCount += 1
        }

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
    private let entriesDirectoryURL: URL?

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.entriesDirectoryURL = nil
    }

    init(fileManager: FileManager = .default, baseDirectoryURL: URL?) {
        self.fileManager = fileManager
        self.entriesDirectoryURL = baseDirectoryURL
    }

    init(fileManager: FileManager = .default, entriesDirectoryURL: URL?) {
        self.fileManager = fileManager
        self.entriesDirectoryURL = entriesDirectoryURL
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
        guard let imageURL = resolvedFileURL(for: imagePath),
              let image = UIImage(contentsOfFile: imageURL.path)
        else {
            throw CocoaError(.fileReadCorruptFile)
        }

        try validateFileName(fileName)
        return try saveImageData(makeThumbnailJPEGData(from: image), fileName: fileName)
    }

    func deleteFileIfExists(at path: String) throws {
        guard let fileURL = resolvedFileURL(for: path),
              fileManager.fileExists(atPath: fileURL.path)
        else {
            return
        }

        try fileManager.removeItem(at: fileURL)
    }

    func mediaReference(for fileURL: URL) throws -> String {
        let entriesDirectory = try makeEntriesDirectoryIfNeeded()
        let standardizedURL = fileURL.standardizedFileURL

        guard isURL(standardizedURL, containedIn: entriesDirectory) else {
            return standardizedURL.lastPathComponent
        }

        return standardizedURL.lastPathComponent
    }

    func normalizedMediaReference(for reference: String) -> String {
        let trimmedReference = reference.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmedReference.isEmpty == false else {
            return reference
        }

        if let fileURL = URL(string: trimmedReference), fileURL.isFileURL {
            return fileURL.lastPathComponent
        }

        let fileName = URL(fileURLWithPath: trimmedReference).lastPathComponent
        return fileName.isEmpty ? trimmedReference : fileName
    }

    func resolvedFileURL(for reference: String) -> URL? {
        let fileName = normalizedMediaReference(for: reference)

        guard fileName.isEmpty == false,
              fileName != ".",
              fileName != "..",
              fileName.contains("/") == false
        else {
            return nil
        }

        guard let directory = try? makeEntriesDirectoryIfNeeded() else {
            return nil
        }

        let fileURL = directory.appending(path: fileName).standardizedFileURL
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }

        return fileURL
    }

    func resolvedThumbnailFileURL(thumbnailReference: String?, imageReference: String) -> URL? {
        if let thumbnailReference,
           let thumbnailURL = resolvedFileURL(for: thumbnailReference) {
            return thumbnailURL
        }

        return resolvedFileURL(for: imageReference)
    }

    @discardableResult
    func performLaunchMaintenance(entryRepository: EntryRepository = EntryRepository()) async -> MaintenanceResult {
        var result = MaintenanceResult()

        do {
            try await migrateMediaReferences(entryRepository: entryRepository, result: &result)
            let entries = try await entryRepository.fetchAllActiveEntries()

            for entry in entries where entry.thumbnailLocalPath == nil {
                await backfillThumbnailIfNeeded(for: entry, entryRepository: entryRepository, result: &result)
            }

            let refreshedEntries = try await entryRepository.fetchAllActiveEntries()
            deleteOrphanFiles(referencedFileNames: referencedMediaFileNames(from: refreshedEntries), result: &result)
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
            let thumbnailReference = try mediaReference(for: thumbnailURL)
            let didUpdate = try await entryRepository.setThumbnailLocalPath(
                thumbnailReference,
                for: entry.localDateString,
                matchingImageLocalPath: entry.imageLocalPath
            )

            if didUpdate {
                result.recordBackfilledThumbnail()
            } else {
                try? deleteFileIfExists(at: thumbnailReference)
            }
        } catch {
            result.recordFailure()
        }
    }

    private func migrateMediaReferences(entryRepository: EntryRepository, result: inout MaintenanceResult) async throws {
        try await entryRepository.store.update { snapshot in
            for index in snapshot.entries.indices {
                let imageReference = normalizedMediaReference(for: snapshot.entries[index].imageLocalPath)
                if imageReference != snapshot.entries[index].imageLocalPath {
                    snapshot.entries[index].imageLocalPath = imageReference
                    result.recordMigratedReference()
                }

                if let thumbnailLocalPath = snapshot.entries[index].thumbnailLocalPath {
                    let thumbnailReference = normalizedMediaReference(for: thumbnailLocalPath)
                    if thumbnailReference != thumbnailLocalPath {
                        snapshot.entries[index].thumbnailLocalPath = thumbnailReference
                        result.recordMigratedReference()
                    }
                }
            }
        }
    }

    private func referencedMediaFileNames(from entries: [DailyPhotoEntry]) -> Set<String> {
        Set(entries.flatMap { entry in
            [entry.imageLocalPath, entry.thumbnailLocalPath].compactMap { reference in
                reference.map(normalizedMediaReference)
            }
        })
    }

    private func deleteOrphanFiles(referencedFileNames: Set<String>, result: inout MaintenanceResult) {
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

                    guard referencedFileNames.contains(fileURL.lastPathComponent) == false else {
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

    private func isURL(_ fileURL: URL, containedIn directory: URL) -> Bool {
        let directoryPath = directory.standardizedFileURL.path
        let filePath = fileURL.standardizedFileURL.path
        return filePath == directoryPath || filePath.hasPrefix(directoryPath + "/")
    }

    private func baseDirectory() throws -> URL {
        if let entriesDirectoryURL {
            return entriesDirectoryURL
        }

        guard let directory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw CocoaError(.fileNoSuchFile)
        }

        return directory
            .appending(path: "DailyFrame")
            .appending(path: "Entries")
    }
}
