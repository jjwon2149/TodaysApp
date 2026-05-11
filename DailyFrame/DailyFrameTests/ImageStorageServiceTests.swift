import ImageIO
import UniformTypeIdentifiers
import UIKit
import XCTest
@testable import DailyFrame

final class ImageStorageServiceTests: XCTestCase {
    private var temporaryDirectory: URL!
    private var service: ImageStorageService!

    override func setUpWithError() throws {
        try super.setUpWithError()

        temporaryDirectory = FileManager.default.temporaryDirectory
            .appending(path: "DailyFrameImageTests-\(UUID().uuidString)")
        service = ImageStorageService(baseDirectoryURL: temporaryDirectory)
    }

    override func tearDownWithError() throws {
        if let temporaryDirectory {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }

        service = nil
        temporaryDirectory = nil

        try super.tearDownWithError()
    }

    func testSaveEntryImageReencodesImageAndStripsGPSMetadata() throws {
        let inputData = try makeJPEGDataWithGPSMetadata(size: CGSize(width: 3_000, height: 1_500))
        let storedImage = try service.saveEntryImageData(
            inputData,
            imageFileName: "2026-05-11-image.jpg",
            thumbnailFileName: "2026-05-11-image-thumbnail.jpg"
        )

        let outputData = try Data(contentsOf: storedImage.imageURL)
        let outputProperties = try imageProperties(from: outputData)
        XCTAssertNil(outputProperties[kCGImagePropertyGPSDictionary as String])

        let outputImage = try XCTUnwrap(UIImage(contentsOfFile: storedImage.imageURL.path))
        XCTAssertEqual(max(outputImage.size.width, outputImage.size.height), 2_048)

        let thumbnailImage = try XCTUnwrap(UIImage(contentsOfFile: storedImage.thumbnailURL.path))
        XCTAssertEqual(thumbnailImage.size.width, ImageStorageService.Policy.thumbnailPixelSize)
        XCTAssertEqual(thumbnailImage.size.height, ImageStorageService.Policy.thumbnailPixelSize)
    }

    func testSaveEntryImageRejectsNestedFileNames() throws {
        let inputData = try makeJPEGDataWithGPSMetadata(size: CGSize(width: 64, height: 64))

        XCTAssertThrowsError(
            try service.saveEntryImageData(
                inputData,
                imageFileName: "../entry.jpg",
                thumbnailFileName: "entry-thumbnail.jpg"
            )
        )
    }

    private func makeJPEGDataWithGPSMetadata(size: CGSize) throws -> Data {
        let image = UIGraphicsImageRenderer(size: size).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }

        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ), let cgImage = image.cgImage else {
            throw CocoaError(.fileWriteUnknown)
        }

        let metadata = [
            kCGImagePropertyGPSDictionary: [
                kCGImagePropertyGPSLatitude: 37.5665,
                kCGImagePropertyGPSLongitude: 126.9780
            ]
        ] as CFDictionary

        CGImageDestinationAddImage(destination, cgImage, metadata)

        guard CGImageDestinationFinalize(destination) else {
            throw CocoaError(.fileWriteUnknown)
        }

        return data as Data
    }

    private func imageProperties(from data: Data) throws -> [String: Any] {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any]
        else {
            throw CocoaError(.fileReadCorruptFile)
        }

        return properties
    }
}
