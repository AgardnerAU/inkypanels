import Foundation

/// Manages extraction of archive entries with windowed caching
/// Keeps only nearby pages extracted to minimize disk usage
actor ExtractionCache {

    // MARK: - Properties

    /// Number of pages to keep on each side of current page
    private let windowSize: Int

    /// Currently extracted files: entry.id -> file URL
    private var extractedFiles: [String: CachedEntry] = [:]

    /// The reader used for extraction
    private weak var reader: (any ArchiveReader)?

    /// All entries in order
    private var entries: [ArchiveEntry] = []

    // MARK: - Types

    private struct CachedEntry {
        let url: URL
        let index: Int
        let accessTime: Date
    }

    // MARK: - Initialization

    init(windowSize: Int = 5) {
        self.windowSize = windowSize
    }

    /// Configure with reader and entries
    func configure(reader: any ArchiveReader, entries: [ArchiveEntry]) {
        self.reader = reader
        self.entries = entries
    }

    // MARK: - Public Methods

    /// Get the file URL for an entry, extracting if necessary
    func url(for entry: ArchiveEntry) async throws -> URL {
        // Return cached if available
        if let cached = extractedFiles[entry.id] {
            // Update access time
            extractedFiles[entry.id] = CachedEntry(
                url: cached.url,
                index: cached.index,
                accessTime: Date()
            )
            return cached.url
        }

        // Extract the entry
        guard let reader = reader else {
            throw InkyPanelsError.reader(.pageLoadFailed(index: entry.index))
        }

        let url = try await reader.extractEntry(entry)

        // Cache the result
        extractedFiles[entry.id] = CachedEntry(
            url: url,
            index: entry.index,
            accessTime: Date()
        )

        // Evict pages outside window
        await evictOutsideWindow(currentIndex: entry.index)

        return url
    }

    /// Get URL for entry by index
    func url(forIndex index: Int) async throws -> URL {
        guard index >= 0 && index < entries.count else {
            throw InkyPanelsError.reader(.invalidPageIndex(index))
        }

        return try await url(for: entries[index])
    }

    /// Prefetch entries around current position
    func prefetch(around index: Int) async {
        let startIndex = max(0, index - windowSize)
        let endIndex = min(entries.count - 1, index + windowSize)

        for i in startIndex...endIndex {
            // Skip if already cached
            let entry = entries[i]
            if extractedFiles[entry.id] != nil {
                continue
            }

            // Extract in background, ignore errors
            _ = try? await url(for: entry)
        }
    }

    /// Clear all cached files
    func clearAll() async {
        for cached in extractedFiles.values {
            try? FileManager.default.removeItem(at: cached.url)
        }
        extractedFiles.removeAll()
    }

    /// Number of currently cached pages
    var cachedCount: Int {
        extractedFiles.count
    }

    // MARK: - Private Methods

    private func evictOutsideWindow(currentIndex: Int) async {
        let keepRange = (currentIndex - windowSize * 2)...(currentIndex + windowSize * 2)

        let entriesToEvict = extractedFiles.filter { _, cached in
            !keepRange.contains(cached.index)
        }

        for (id, cached) in entriesToEvict {
            try? FileManager.default.removeItem(at: cached.url)
            extractedFiles.removeValue(forKey: id)
        }
    }
}
