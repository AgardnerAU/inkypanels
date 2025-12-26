import Foundation
import SwiftData

/// Service for persisting reading progress using SwiftData
@MainActor
final class ProgressService: ProgressServiceProtocol {

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - ProgressServiceProtocol

    func saveProgress(for filePath: String, currentPage: Int, totalPages: Int) async {
        // Try to find existing record
        let descriptor = FetchDescriptor<ProgressRecord>(
            predicate: #Predicate { $0.filePath == filePath }
        )

        do {
            let existing = try modelContext.fetch(descriptor)

            if let record = existing.first {
                // Update existing record
                record.currentPage = currentPage
                record.totalPages = totalPages
                record.lastReadDate = Date()
                record.isCompleted = currentPage >= totalPages - 1
            } else {
                // Create new record
                let record = ProgressRecord(
                    filePath: filePath,
                    currentPage: currentPage,
                    totalPages: totalPages,
                    lastReadDate: Date(),
                    isCompleted: currentPage >= totalPages - 1
                )
                modelContext.insert(record)
            }

            try modelContext.save()
        } catch {
            // Silently fail - progress saving is not critical
            print("Failed to save progress: \(error)")
        }
    }

    func loadProgress(for filePath: String) async -> ProgressRecord? {
        let descriptor = FetchDescriptor<ProgressRecord>(
            predicate: #Predicate { $0.filePath == filePath }
        )

        do {
            let results = try modelContext.fetch(descriptor)
            return results.first
        } catch {
            print("Failed to load progress: \(error)")
            return nil
        }
    }

    func toggleBookmark(for filePath: String, at page: Int) async {
        let descriptor = FetchDescriptor<ProgressRecord>(
            predicate: #Predicate { $0.filePath == filePath }
        )

        do {
            let existing = try modelContext.fetch(descriptor)

            if let record = existing.first {
                if record.bookmarks.contains(page) {
                    record.bookmarks.removeAll { $0 == page }
                } else {
                    record.bookmarks.append(page)
                    record.bookmarks.sort()
                }
                try modelContext.save()
            }
        } catch {
            print("Failed to toggle bookmark: \(error)")
        }
    }

    func isBookmarked(for filePath: String, page: Int) async -> Bool {
        guard let record = await loadProgress(for: filePath) else {
            return false
        }
        return record.bookmarks.contains(page)
    }

    func bookmarks(for filePath: String) async -> [Int] {
        guard let record = await loadProgress(for: filePath) else {
            return []
        }
        return record.bookmarks
    }

    func deleteProgress(for filePath: String) async {
        let descriptor = FetchDescriptor<ProgressRecord>(
            predicate: #Predicate { $0.filePath == filePath }
        )

        do {
            let existing = try modelContext.fetch(descriptor)
            for record in existing {
                modelContext.delete(record)
            }
            try modelContext.save()
        } catch {
            print("Failed to delete progress: \(error)")
        }
    }

    /// Get recently read files sorted by last read date
    func recentFiles(limit: Int = 20) async -> [ProgressRecord] {
        var descriptor = FetchDescriptor<ProgressRecord>(
            sortBy: [SortDescriptor(\ProgressRecord.lastReadDate, order: .reverse)]
        )
        descriptor.fetchLimit = limit

        do {
            return try modelContext.fetch(descriptor)
        } catch {
            print("Failed to fetch recent files: \(error)")
            return []
        }
    }
}
