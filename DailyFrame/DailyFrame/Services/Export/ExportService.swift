import Foundation

struct ExportService {
    struct ExportResult {
        let fileURL: URL
        let manifest: DailyFrameExportManifest
        let mediaFileCount: Int

        var entryCount: Int {
            manifest.entries.count
        }

        var warningCount: Int {
            manifest.warnings.count
        }
    }

    enum ExportError: Error {
        case fileNameEncodingFailed(String)
        case fileTooLarge(String)
        case tooManyFiles
    }

    private struct MediaFile {
        let sourceURL: URL
        let archivePath: String
    }

    private let entryRepository: EntryRepository
    private let imageStorageService: ImageStorageService
    private let fileManager: FileManager
    private let nowProvider: () -> Date

    init(
        entryRepository: EntryRepository = EntryRepository(),
        imageStorageService: ImageStorageService = ImageStorageService(),
        fileManager: FileManager = .default,
        nowProvider: @escaping () -> Date = { .now }
    ) {
        self.entryRepository = entryRepository
        self.imageStorageService = imageStorageService
        self.fileManager = fileManager
        self.nowProvider = nowProvider
    }

    func exportArchive() async throws -> ExportResult {
        let entries = try await entryRepository.fetchAllActiveEntries()
        let generatedAt = nowProvider()
        var mediaFiles: [MediaFile] = []
        var archivePathBySourcePath: [String: String] = [:]
        var usedArchiveFileNames = Set<String>()
        var warnings: [DailyFrameExportManifest.Warning] = []
        var manifestEntries: [DailyFrameExportManifest.Entry] = []

        for entry in entries {
            var imagePath: String?
            var thumbnailPath: String?

            if let imageURL = imageStorageService.resolvedFileURL(for: entry.imageLocalPath) {
                imagePath = addMediaFile(
                    imageURL,
                    fallbackFileName: "\(entry.localDateString).jpg",
                    mediaFiles: &mediaFiles,
                    archivePathBySourcePath: &archivePathBySourcePath,
                    usedArchiveFileNames: &usedArchiveFileNames
                )
            } else {
                warnings.append(.init(
                    localDateString: entry.localDateString,
                    code: "image_missing",
                    message: "Image file was not found in the current Entries directory."
                ))
            }

            if let thumbnailLocalPath = entry.thumbnailLocalPath {
                if let thumbnailURL = imageStorageService.resolvedFileURL(for: thumbnailLocalPath) {
                    thumbnailPath = addMediaFile(
                        thumbnailURL,
                        fallbackFileName: "\(entry.localDateString)-thumbnail.jpg",
                        mediaFiles: &mediaFiles,
                        archivePathBySourcePath: &archivePathBySourcePath,
                        usedArchiveFileNames: &usedArchiveFileNames
                    )
                } else if let imagePath {
                    thumbnailPath = imagePath
                    warnings.append(.init(
                        localDateString: entry.localDateString,
                        code: "thumbnail_missing_using_image",
                        message: "Thumbnail file was missing; the original image is used as the thumbnail fallback."
                    ))
                } else {
                    warnings.append(.init(
                        localDateString: entry.localDateString,
                        code: "thumbnail_missing",
                        message: "Thumbnail file was missing and no original image fallback was available."
                    ))
                }
            } else if let imagePath {
                thumbnailPath = imagePath
            }

            manifestEntries.append(.init(
                id: entry.id,
                localDateString: entry.localDateString,
                createdAtUTC: entry.createdAtUTC,
                updatedAtUTC: entry.updatedAtUTC,
                timezoneIdentifier: entry.timezoneIdentifier,
                timezoneOffsetMinutes: entry.timezoneOffsetMinutes,
                memo: entry.memo,
                moodCode: entry.moodCode,
                missionId: entry.missionId,
                missionCompleted: entry.missionCompleted,
                sourceType: entry.sourceType,
                media: .init(
                    imagePath: imagePath,
                    thumbnailPath: thumbnailPath
                )
            ))
        }

        let manifest = DailyFrameExportManifest(
            generatedAtUTC: generatedAt,
            entries: manifestEntries,
            warnings: warnings
        )
        let manifestData = try makeManifestData(manifest)
        let archiveURL = exportArchiveURL(generatedAt: generatedAt)

        try? fileManager.removeItem(at: archiveURL)

        var writer = try ZipArchiveWriter(destinationURL: archiveURL, fileManager: fileManager)
        try writer.addFile(data: manifestData, archivePath: "manifest.json", modifiedAt: generatedAt)

        for mediaFile in mediaFiles {
            let data = try Data(contentsOf: mediaFile.sourceURL)
            try writer.addFile(data: data, archivePath: mediaFile.archivePath, modifiedAt: generatedAt)
        }

        try writer.close()

        return ExportResult(
            fileURL: archiveURL,
            manifest: manifest,
            mediaFileCount: mediaFiles.count
        )
    }

    private func addMediaFile(
        _ sourceURL: URL,
        fallbackFileName: String,
        mediaFiles: inout [MediaFile],
        archivePathBySourcePath: inout [String: String],
        usedArchiveFileNames: inout Set<String>
    ) -> String {
        let sourcePath = sourceURL.standardizedFileURL.path

        if let archivePath = archivePathBySourcePath[sourcePath] {
            return archivePath
        }

        let fileName = uniqueArchiveFileName(
            preferredFileName: sanitizedArchiveFileName(sourceURL.lastPathComponent, fallback: fallbackFileName),
            usedArchiveFileNames: &usedArchiveFileNames
        )
        let archivePath = "Media/\(fileName)"
        archivePathBySourcePath[sourcePath] = archivePath
        mediaFiles.append(MediaFile(sourceURL: sourceURL, archivePath: archivePath))
        return archivePath
    }

    private func sanitizedArchiveFileName(_ fileName: String, fallback: String) -> String {
        let trimmedFileName = fileName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmedFileName.isEmpty == false,
              trimmedFileName != ".",
              trimmedFileName != ".."
        else {
            return fallback
        }

        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
        let scalars = trimmedFileName.unicodeScalars.map { scalar in
            allowedCharacters.contains(scalar) ? Character(scalar) : "-"
        }
        let sanitized = String(scalars).trimmingCharacters(in: CharacterSet(charactersIn: ".-"))
        return sanitized.isEmpty ? fallback : sanitized
    }

    private func uniqueArchiveFileName(
        preferredFileName: String,
        usedArchiveFileNames: inout Set<String>
    ) -> String {
        guard usedArchiveFileNames.insert(preferredFileName).inserted == false else {
            return preferredFileName
        }

        let url = URL(fileURLWithPath: preferredFileName)
        let baseName = url.deletingPathExtension().lastPathComponent
        let pathExtension = url.pathExtension
        var counter = 2

        while true {
            let candidate = pathExtension.isEmpty
                ? "\(baseName)-\(counter)"
                : "\(baseName)-\(counter).\(pathExtension)"

            if usedArchiveFileNames.insert(candidate).inserted {
                return candidate
            }

            counter += 1
        }
    }

    private func makeManifestData(_ manifest: DailyFrameExportManifest) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(manifest)
    }

    private func exportArchiveURL(generatedAt: Date) -> URL {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd-HHmmss"

        return fileManager.temporaryDirectory
            .appending(path: "DailyFrame-Export-\(formatter.string(from: generatedAt)).zip")
    }
}

struct DailyFrameExportManifest: Codable, Equatable {
    struct Entry: Codable, Equatable {
        struct Media: Codable, Equatable {
            let imagePath: String?
            let thumbnailPath: String?
        }

        let id: UUID
        let localDateString: String
        let createdAtUTC: Date
        let updatedAtUTC: Date
        let timezoneIdentifier: String
        let timezoneOffsetMinutes: Int
        let memo: String?
        let moodCode: String?
        let missionId: String?
        let missionCompleted: Bool
        let sourceType: String
        let media: Media
    }

    struct Warning: Codable, Equatable {
        let localDateString: String
        let code: String
        let message: String
    }

    let schemaVersion: Int
    let generatedAtUTC: Date
    let mediaReferenceBase: String
    let entries: [Entry]
    let warnings: [Warning]

    init(generatedAtUTC: Date, entries: [Entry], warnings: [Warning]) {
        self.schemaVersion = 1
        self.generatedAtUTC = generatedAtUTC
        self.mediaReferenceBase = "archive-root"
        self.entries = entries
        self.warnings = warnings
    }
}

private struct ZipArchiveWriter {
    private struct CentralDirectoryEntry {
        let archivePathData: Data
        let checksum: UInt32
        let size: UInt32
        let modifiedTime: UInt16
        let modifiedDate: UInt16
        let localHeaderOffset: UInt32
    }

    private let fileHandle: FileHandle
    private var centralDirectoryEntries: [CentralDirectoryEntry] = []
    private var currentOffset: UInt32 = 0

    init(destinationURL: URL, fileManager: FileManager) throws {
        let directoryURL = destinationURL.deletingLastPathComponent()

        if fileManager.fileExists(atPath: directoryURL.path) == false {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        }

        fileManager.createFile(atPath: destinationURL.path, contents: nil)
        fileHandle = try FileHandle(forWritingTo: destinationURL)
    }

    mutating func addFile(data: Data, archivePath: String, modifiedAt: Date) throws {
        guard data.count <= Int(UInt32.max) else {
            throw ExportService.ExportError.fileTooLarge(archivePath)
        }

        guard let archivePathData = archivePath.data(using: .utf8) else {
            throw ExportService.ExportError.fileNameEncodingFailed(archivePath)
        }

        guard archivePathData.count <= Int(UInt16.max) else {
            throw ExportService.ExportError.fileNameEncodingFailed(archivePath)
        }

        let checksum = CRC32.checksum(data)
        let size = UInt32(data.count)
        let timestamp = Self.dosTimestamp(from: modifiedAt)
        let localHeaderOffset = currentOffset
        var localHeader = Data()
        localHeader.appendUInt32(0x04034b50)
        localHeader.appendUInt16(20)
        localHeader.appendUInt16(0x0800)
        localHeader.appendUInt16(0)
        localHeader.appendUInt16(timestamp.time)
        localHeader.appendUInt16(timestamp.date)
        localHeader.appendUInt32(checksum)
        localHeader.appendUInt32(size)
        localHeader.appendUInt32(size)
        localHeader.appendUInt16(UInt16(archivePathData.count))
        localHeader.appendUInt16(0)
        localHeader.append(archivePathData)

        try write(localHeader)
        try write(data)

        centralDirectoryEntries.append(.init(
            archivePathData: archivePathData,
            checksum: checksum,
            size: size,
            modifiedTime: timestamp.time,
            modifiedDate: timestamp.date,
            localHeaderOffset: localHeaderOffset
        ))
    }

    mutating func close() throws {
        guard centralDirectoryEntries.count <= Int(UInt16.max) else {
            throw ExportService.ExportError.tooManyFiles
        }

        let centralDirectoryOffset = currentOffset
        var centralDirectory = Data()

        for entry in centralDirectoryEntries {
            centralDirectory.appendUInt32(0x02014b50)
            centralDirectory.appendUInt16(20)
            centralDirectory.appendUInt16(20)
            centralDirectory.appendUInt16(0x0800)
            centralDirectory.appendUInt16(0)
            centralDirectory.appendUInt16(entry.modifiedTime)
            centralDirectory.appendUInt16(entry.modifiedDate)
            centralDirectory.appendUInt32(entry.checksum)
            centralDirectory.appendUInt32(entry.size)
            centralDirectory.appendUInt32(entry.size)
            centralDirectory.appendUInt16(UInt16(entry.archivePathData.count))
            centralDirectory.appendUInt16(0)
            centralDirectory.appendUInt16(0)
            centralDirectory.appendUInt16(0)
            centralDirectory.appendUInt16(0)
            centralDirectory.appendUInt32(0)
            centralDirectory.appendUInt32(entry.localHeaderOffset)
            centralDirectory.append(entry.archivePathData)
        }

        guard centralDirectory.count <= Int(UInt32.max) else {
            throw ExportService.ExportError.fileTooLarge("central-directory")
        }

        try write(centralDirectory)

        var endOfCentralDirectory = Data()
        endOfCentralDirectory.appendUInt32(0x06054b50)
        endOfCentralDirectory.appendUInt16(0)
        endOfCentralDirectory.appendUInt16(0)
        endOfCentralDirectory.appendUInt16(UInt16(centralDirectoryEntries.count))
        endOfCentralDirectory.appendUInt16(UInt16(centralDirectoryEntries.count))
        endOfCentralDirectory.appendUInt32(UInt32(centralDirectory.count))
        endOfCentralDirectory.appendUInt32(centralDirectoryOffset)
        endOfCentralDirectory.appendUInt16(0)
        try write(endOfCentralDirectory)
        try fileHandle.close()
    }

    private mutating func write(_ data: Data) throws {
        guard data.count <= Int(UInt32.max) - Int(currentOffset) else {
            throw ExportService.ExportError.fileTooLarge("archive")
        }

        try fileHandle.write(contentsOf: data)
        currentOffset += UInt32(data.count)
    }

    private static func dosTimestamp(from date: Date) -> (time: UInt16, date: UInt16) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let year = max((components.year ?? 1980) - 1980, 0)
        let month = components.month ?? 1
        let day = components.day ?? 1
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        let second = (components.second ?? 0) / 2

        return (
            time: UInt16((hour << 11) | (minute << 5) | second),
            date: UInt16((year << 9) | (month << 5) | day)
        )
    }
}

private enum CRC32 {
    private static let table: [UInt32] = (0..<256).map { index in
        var value = UInt32(index)

        for _ in 0..<8 {
            if value & 1 == 1 {
                value = 0xedb88320 ^ (value >> 1)
            } else {
                value >>= 1
            }
        }

        return value
    }

    static func checksum(_ data: Data) -> UInt32 {
        var checksum: UInt32 = 0xffffffff

        for byte in data {
            checksum = table[Int((checksum ^ UInt32(byte)) & 0xff)] ^ (checksum >> 8)
        }

        return checksum ^ 0xffffffff
    }
}

private extension Data {
    mutating func appendUInt16(_ value: UInt16) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) { bytes in
            append(contentsOf: bytes)
        }
    }

    mutating func appendUInt32(_ value: UInt32) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) { bytes in
            append(contentsOf: bytes)
        }
    }
}
