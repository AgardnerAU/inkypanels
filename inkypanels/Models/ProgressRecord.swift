import Foundation
import SwiftData

/// SwiftData model for persisted reading progress
@Model
final class ProgressRecord {
    /// The file URL path as identifier (stable across launches)
    @Attribute(.unique) var filePath: String

    /// Current page index (0-based)
    var currentPage: Int

    /// Total pages in the comic
    var totalPages: Int

    /// Last time this comic was read
    var lastReadDate: Date

    /// Whether the comic has been completed
    var isCompleted: Bool

    /// Bookmarked page indices
    var bookmarks: [Int]

    init(
        filePath: String,
        currentPage: Int = 0,
        totalPages: Int,
        lastReadDate: Date = Date(),
        isCompleted: Bool = false,
        bookmarks: [Int] = []
    ) {
        self.filePath = filePath
        self.currentPage = currentPage
        self.totalPages = totalPages
        self.lastReadDate = lastReadDate
        self.isCompleted = isCompleted
        self.bookmarks = bookmarks
    }

    /// Percentage complete (0-100)
    var percentComplete: Double {
        guard totalPages > 0 else { return 0 }
        return Double(currentPage + 1) / Double(totalPages) * 100
    }
}
