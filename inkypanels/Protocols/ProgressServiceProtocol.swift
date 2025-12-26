import Foundation

/// Protocol for reading progress persistence
/// Uses file path as stable identifier across app launches
@MainActor
protocol ProgressServiceProtocol: Sendable {
    /// Save reading progress for a comic at the given file path
    func saveProgress(for filePath: String, currentPage: Int, totalPages: Int) async

    /// Load reading progress for a comic by file path
    func loadProgress(for filePath: String) async -> ProgressRecord?

    /// Toggle bookmark at the specified page
    func toggleBookmark(for filePath: String, at page: Int) async

    /// Check if a page is bookmarked
    func isBookmarked(for filePath: String, page: Int) async -> Bool

    /// Get all bookmarks for a comic
    func bookmarks(for filePath: String) async -> [Int]

    /// Delete reading progress for a comic
    func deleteProgress(for filePath: String) async
}
