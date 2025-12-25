import Foundation

/// Tracks reading progress for a comic
struct ReadingProgress: Codable, Hashable, Sendable {
    let comicId: UUID
    var currentPage: Int
    var totalPages: Int
    var lastReadDate: Date
    var isCompleted: Bool
    var bookmarks: [Int]

    /// Percentage of comic completed (0-100)
    var percentComplete: Double {
        guard totalPages > 0 else { return 0 }
        return Double(currentPage) / Double(totalPages) * 100
    }

    /// Whether the comic has been started
    var hasStarted: Bool {
        currentPage > 0
    }

    init(
        comicId: UUID,
        currentPage: Int = 0,
        totalPages: Int,
        lastReadDate: Date = Date(),
        isCompleted: Bool = false,
        bookmarks: [Int] = []
    ) {
        self.comicId = comicId
        self.currentPage = currentPage
        self.totalPages = totalPages
        self.lastReadDate = lastReadDate
        self.isCompleted = isCompleted
        self.bookmarks = bookmarks
    }

    /// Add a bookmark at the specified page
    mutating func addBookmark(at page: Int) {
        guard !bookmarks.contains(page) else { return }
        bookmarks.append(page)
        bookmarks.sort()
    }

    /// Remove a bookmark at the specified page
    mutating func removeBookmark(at page: Int) {
        bookmarks.removeAll { $0 == page }
    }

    /// Toggle bookmark at the specified page
    mutating func toggleBookmark(at page: Int) {
        if bookmarks.contains(page) {
            removeBookmark(at: page)
        } else {
            addBookmark(at: page)
        }
    }
}
