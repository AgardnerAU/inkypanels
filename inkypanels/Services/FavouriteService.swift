import Foundation
import SwiftData

/// Service for managing favourite files using SwiftData
@MainActor
final class FavouriteService {

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Public Methods

    /// Check if a file is favourited
    func isFavourite(filePath: String) async -> Bool {
        let descriptor = FetchDescriptor<FavouriteRecord>(
            predicate: #Predicate { $0.filePath == filePath }
        )

        do {
            let results = try modelContext.fetch(descriptor)
            return !results.isEmpty
        } catch {
            return false
        }
    }

    /// Toggle favourite status for a file
    func toggleFavourite(filePath: String) async {
        let descriptor = FetchDescriptor<FavouriteRecord>(
            predicate: #Predicate { $0.filePath == filePath }
        )

        do {
            let results = try modelContext.fetch(descriptor)

            if let existing = results.first {
                // Remove from favourites
                modelContext.delete(existing)
            } else {
                // Add to favourites
                let record = FavouriteRecord(filePath: filePath)
                modelContext.insert(record)
            }

            try modelContext.save()
        } catch {
            // Silently fail
        }
    }

    /// Add a file to favourites
    func addFavourite(filePath: String) async {
        // Check if already exists
        if await isFavourite(filePath: filePath) {
            return
        }

        let record = FavouriteRecord(filePath: filePath)
        modelContext.insert(record)

        do {
            try modelContext.save()
        } catch {
            // Silently fail
        }
    }

    /// Remove a file from favourites
    func removeFavourite(filePath: String) async {
        let descriptor = FetchDescriptor<FavouriteRecord>(
            predicate: #Predicate { $0.filePath == filePath }
        )

        do {
            let results = try modelContext.fetch(descriptor)
            for record in results {
                modelContext.delete(record)
            }
            try modelContext.save()
        } catch {
            // Silently fail
        }
    }

    /// Get all favourite file paths
    func allFavourites() async -> [String] {
        let descriptor = FetchDescriptor<FavouriteRecord>(
            sortBy: [SortDescriptor(\.addedDate, order: .reverse)]
        )

        do {
            let results = try modelContext.fetch(descriptor)
            return results.map { $0.filePath }
        } catch {
            return []
        }
    }

    /// Get favourite status for multiple files at once (more efficient)
    func favouriteStatus(for filePaths: [String]) async -> Set<String> {
        let descriptor = FetchDescriptor<FavouriteRecord>()

        do {
            let results = try modelContext.fetch(descriptor)
            let favouritePaths = Set(results.map { $0.filePath })
            return favouritePaths.intersection(filePaths)
        } catch {
            return []
        }
    }
}
