import Foundation
import UIKit

struct ImageStorageService {
    struct StoredEntryImage {
        let imageURL: URL
        let thumbnailURL: URL
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

    private func baseDirectory() throws -> URL {
        guard let directory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw CocoaError(.fileNoSuchFile)
        }

        return directory
            .appending(path: "DailyFrame")
            .appending(path: "Entries")
    }
}
