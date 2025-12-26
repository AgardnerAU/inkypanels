import CryptoKit
import Foundation
import UIKit

/// Service for generating and caching comic thumbnails
/// Extracts first page of each comic and caches as JPEG
actor ThumbnailService: ThumbnailServiceProtocol {

    // MARK: - Properties

    private let cacheDirectory: URL
    private let thumbnailSize: CGSize
    private let jpegQuality: CGFloat = 0.8

    /// In-memory cache for recently accessed thumbnails
    private var memoryCache: [String: Data] = [:]
    private let memoryCacheLimit = 50

    // MARK: - Initialization

    init(thumbnailSize: CGSize = Constants.Cache.defaultThumbnailSize) {
        self.thumbnailSize = thumbnailSize

        // Use Caches directory for thumbnails
        let cachesURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        self.cacheDirectory = cachesURL.appendingPathComponent(Constants.Paths.thumbnailsFolder, isDirectory: true)

        // Create cache directory
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    // MARK: - ThumbnailServiceProtocol

    func thumbnail(for file: ComicFile) async throws -> Data {
        let cacheKey = cacheKey(for: file)

        // Check memory cache first
        if let cached = memoryCache[cacheKey] {
            return cached
        }

        // Check disk cache
        let cacheURL = cacheDirectory.appendingPathComponent(cacheKey + ".jpg")
        if FileManager.default.fileExists(atPath: cacheURL.path),
           let data = try? Data(contentsOf: cacheURL) {
            // Add to memory cache
            addToMemoryCache(key: cacheKey, data: data)
            return data
        }

        // Generate thumbnail
        let thumbnailData = try await generateThumbnailForFile(file)

        // Save to disk cache
        try? thumbnailData.write(to: cacheURL, options: .atomic)

        // Add to memory cache
        addToMemoryCache(key: cacheKey, data: thumbnailData)

        return thumbnailData
    }

    func generateThumbnail(from imageData: Data, size: CGSize) async throws -> Data {
        guard let image = UIImage(data: imageData) else {
            throw ThumbnailError.invalidImageData
        }

        return try await resizeImage(image, to: size)
    }

    func clearCache() async {
        memoryCache.removeAll()
        try? FileManager.default.removeItem(at: cacheDirectory)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    func cacheSize() async -> Int64 {
        var totalSize: Int64 = 0

        guard let enumerator = FileManager.default.enumerator(
            at: cacheDirectory,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }

        // Convert to array to avoid makeIterator issue in async context (Swift 6)
        let fileURLs = enumerator.allObjects.compactMap { $0 as? URL }

        for fileURL in fileURLs {
            if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                totalSize += Int64(size)
            }
        }

        return totalSize
    }

    func pruneCache(existingFiles: [ComicFile]) async {
        let validKeys = Set(existingFiles.map { cacheKey(for: $0) })

        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: nil
        ) else {
            return
        }

        for url in contents {
            let fileName = url.deletingPathExtension().lastPathComponent
            if !validKeys.contains(fileName) {
                try? FileManager.default.removeItem(at: url)
            }
        }

        // Prune memory cache
        memoryCache = memoryCache.filter { validKeys.contains($0.key) }
    }

    // MARK: - Background Generation

    /// Generate thumbnails for multiple files in the background
    func generateInBackground(files: [ComicFile]) async {
        for file in files {
            // Skip if already cached
            let cacheKey = cacheKey(for: file)
            let cacheURL = cacheDirectory.appendingPathComponent(cacheKey + ".jpg")

            if FileManager.default.fileExists(atPath: cacheURL.path) {
                continue
            }

            // Generate and cache (ignore errors for background generation)
            _ = try? await thumbnail(for: file)

            // Small delay to avoid overwhelming the system
            try? await Task.sleep(for: .milliseconds(50))
        }
    }

    // MARK: - Private Methods

    private func cacheKey(for file: ComicFile) -> String {
        let hash = SHA256.hash(data: Data(file.url.path.utf8))
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    private func generateThumbnailForFile(_ file: ComicFile) async throws -> Data {
        // Handle folders and single images differently
        if file.fileType == .folder {
            return try await generateThumbnailForFolder(file.url)
        }

        if file.fileType.isImage {
            return try await generateThumbnailForImage(file.url)
        }

        // For archives/PDFs, extract first page
        return try await generateThumbnailForArchive(file.url)
    }

    private func generateThumbnailForImage(_ url: URL) async throws -> Data {
        guard let image = UIImage(contentsOfFile: url.path) else {
            throw ThumbnailError.invalidImageData
        }

        return try await resizeImage(image, to: thumbnailSize)
    }

    private func generateThumbnailForFolder(_ url: URL) async throws -> Data {
        // Find first image in folder
        let contents = try FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )

        let imageExtensions = ImageReader.supportedExtensions

        let firstImage = contents
            .filter { imageExtensions.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
            .first

        guard let imageURL = firstImage else {
            throw ThumbnailError.noImagesFound
        }

        return try await generateThumbnailForImage(imageURL)
    }

    private func generateThumbnailForArchive(_ url: URL) async throws -> Data {
        let reader = try ArchiveReaderFactory.reader(for: url)
        let entries = try await reader.listEntries()

        guard let firstEntry = entries.first else {
            throw ThumbnailError.noImagesFound
        }

        let imageURL = try await reader.extractEntry(firstEntry)

        guard let image = UIImage(contentsOfFile: imageURL.path) else {
            throw ThumbnailError.invalidImageData
        }

        return try await resizeImage(image, to: thumbnailSize)
    }

    private func resizeImage(_ image: UIImage, to targetSize: CGSize) async throws -> Data {
        // Calculate aspect-fit size
        let widthRatio = targetSize.width / image.size.width
        let heightRatio = targetSize.height / image.size.height
        let ratio = min(widthRatio, heightRatio)

        let newSize = CGSize(
            width: image.size.width * ratio,
            height: image.size.height * ratio
        )

        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resizedImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }

        guard let data = resizedImage.jpegData(compressionQuality: jpegQuality) else {
            throw ThumbnailError.resizeFailed
        }

        return data
    }

    private func addToMemoryCache(key: String, data: Data) {
        // Evict oldest if at limit
        if memoryCache.count >= memoryCacheLimit {
            if let firstKey = memoryCache.keys.first {
                memoryCache.removeValue(forKey: firstKey)
            }
        }
        memoryCache[key] = data
    }
}

// MARK: - Errors

enum ThumbnailError: Error, LocalizedError {
    case invalidImageData
    case noImagesFound
    case resizeFailed

    var errorDescription: String? {
        switch self {
        case .invalidImageData:
            return "Could not read image data"
        case .noImagesFound:
            return "No images found in archive"
        case .resizeFailed:
            return "Failed to resize image"
        }
    }
}
