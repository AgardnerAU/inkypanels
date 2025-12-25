import Foundation
import CoreGraphics

/// Protocol for thumbnail generation and caching
protocol ThumbnailServiceProtocol: Sendable {
    /// Get or generate a thumbnail for a comic file
    func thumbnail(for file: ComicFile) async throws -> Data

    /// Generate a thumbnail from image data
    func generateThumbnail(from imageData: Data, size: CGSize) async throws -> Data

    /// Clear the thumbnail cache
    func clearCache() async

    /// Get the current cache size in bytes
    func cacheSize() async -> Int64

    /// Remove thumbnails for files that no longer exist
    func pruneCache(existingFiles: [ComicFile]) async
}
