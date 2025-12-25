import Foundation

/// Protocol for archive extraction services
protocol ArchiveServiceProtocol: Sendable {
    /// Extract all pages from an archive
    func extractPages(from url: URL) async throws -> [ComicPage]

    /// Extract a single page at the specified index
    func extractPage(at index: Int, from url: URL) async throws -> ComicPage

    /// Get the total page count for an archive
    func pageCount(for url: URL) async throws -> Int

    /// Extract the cover image (first page) from an archive
    func extractCoverImage(from url: URL) async throws -> Data

    /// Get metadata for all pages without extracting image data
    func pageMetadata(for url: URL) async throws -> [ComicPageMetadata]
}
