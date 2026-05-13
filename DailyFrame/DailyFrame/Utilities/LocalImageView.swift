import SwiftUI
import UIKit

struct LocalImageView<Placeholder: View>: View {
    let imagePath: String
    let fallbackImagePath: String?
    let contentMode: ContentMode
    private let placeholder: () -> Placeholder

    @State private var image: UIImage?
    @State private var loadedPath: String?

    init(
        imagePath: String,
        fallbackImagePath: String? = nil,
        contentMode: ContentMode = .fill,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.imagePath = imagePath
        self.fallbackImagePath = fallbackImagePath
        self.contentMode = contentMode
        self.placeholder = placeholder
    }

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                placeholder()
            }
        }
        .clipped()
        .task(id: imagePath) {
            loadedPath = imagePath

            if let cachedImage = LocalImageCache.shared.cachedImage(for: imagePath) {
                image = cachedImage
                return
            }

            image = nil
            let loadedImage = await LocalImageCache.shared.image(for: imagePath, fallbackPath: fallbackImagePath)

            guard Task.isCancelled == false, loadedPath == imagePath else {
                return
            }

            image = loadedImage
        }
    }
}

private final class LocalImageCache {
    static let shared = LocalImageCache()

    private let cache = NSCache<NSString, UIImage>()
    private let imageStorageService = ImageStorageService()

    private init() {
        cache.countLimit = 120
    }

    func cachedImage(for path: String) -> UIImage? {
        cache.object(forKey: cacheKey(for: path))
    }

    func image(for path: String, fallbackPath: String? = nil) async -> UIImage? {
        let key = cacheKey(for: path)

        if let cachedImage = cache.object(forKey: key) {
            return cachedImage
        }

        let resolvedPath = resolvedExistingPath(path) ?? fallbackPath.flatMap(resolvedExistingPath)

        guard let resolvedPath else {
            return nil
        }

        let decodedImage = await Task.detached(priority: .utility) { () -> UIImage? in
            autoreleasepool {
                guard let image = UIImage(contentsOfFile: resolvedPath) else {
                    return nil
                }

                return image.preparingForDisplay() ?? image
            }
        }.value

        if let decodedImage {
            cache.setObject(decodedImage, forKey: key)
        }

        return decodedImage
    }

    private func cacheKey(for path: String) -> NSString {
        URL(fileURLWithPath: path).standardizedFileURL.path as NSString
    }

    private func resolvedExistingPath(_ path: String) -> String? {
        if FileManager.default.fileExists(atPath: path) {
            return path
        }

        return imageStorageService.resolvedFileURL(for: path)?.path
    }
}
