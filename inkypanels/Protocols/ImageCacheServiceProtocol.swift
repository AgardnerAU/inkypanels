import Foundation

/// Protocol for in-memory image caching
protocol ImageCacheServiceProtocol: Sendable {
    /// Cache image data for a key
    func cacheImage(_ data: Data, for key: String) async

    /// Retrieve cached image data for a key
    func retrieveImage(for key: String) async -> Data?

    /// Prefetch pages from an archive for smoother reading
    func prefetchPages(_ indices: [Int], from url: URL) async

    /// Clear all cached images
    func clearCache() async

    /// Get the current number of cached pages
    func cachedPageCount() async -> Int
}
