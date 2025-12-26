import Foundation

/// Priority level for page extraction
enum ExtractionPriority: Int, Comparable {
    case immediate = 0  // Current page and immediate neighbors
    case high = 1       // Near pages (within immediate window)
    case background = 2 // Background prefetch (larger window)

    static func < (lhs: ExtractionPriority, rhs: ExtractionPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Manages extraction of archive entries with two-tier progressive caching
/// - Tier 1 (Immediate): Current page ± immediateWindowSize, loaded concurrently with high priority
/// - Tier 2 (Background): Expands to ± backgroundWindowSize with lower priority
actor ExtractionCache {

    // MARK: - Configuration

    private let immediateWindowSize: Int
    private let backgroundWindowSize: Int
    private let maxConcurrentExtractions: Int
    private let maxCachedPages: Int

    // MARK: - State

    /// Currently extracted files: entry.id -> cached entry
    private var extractedFiles: [String: CachedEntry] = [:]

    /// The reader used for extraction
    private weak var reader: (any ArchiveReader)?

    /// All entries in order
    private var entries: [ArchiveEntry] = []

    /// Current prefetch task (can be cancelled when navigation changes)
    private var prefetchTask: Task<Void, Never>?

    /// Currently extracting entry IDs (to avoid duplicate work)
    private var extractingEntryIDs: Set<String> = []

    // MARK: - Types

    private struct CachedEntry {
        let url: URL
        let index: Int
        let accessTime: Date
    }

    private struct ExtractionRequest {
        let entry: ArchiveEntry
        let priority: ExtractionPriority
    }

    // MARK: - Initialization

    init(
        immediateWindowSize: Int = Constants.Cache.immediateWindowSize,
        backgroundWindowSize: Int = Constants.Cache.backgroundWindowSize,
        maxConcurrentExtractions: Int = Constants.Cache.maxConcurrentExtractions,
        maxCachedPages: Int = Constants.Cache.maxCachedPages
    ) {
        self.immediateWindowSize = immediateWindowSize
        self.backgroundWindowSize = backgroundWindowSize
        self.maxConcurrentExtractions = maxConcurrentExtractions
        self.maxCachedPages = maxCachedPages
    }

    /// Configure with reader and entries
    func configure(reader: any ArchiveReader, entries: [ArchiveEntry]) {
        self.reader = reader
        self.entries = entries
    }

    // MARK: - Public Methods

    /// Get the file URL for an entry, extracting if necessary
    /// This is the primary method - returns quickly if cached, otherwise extracts
    func url(for entry: ArchiveEntry) async throws -> URL {
        // Return cached if available
        if let cached = extractedFiles[entry.id] {
            // Update access time for LRU
            extractedFiles[entry.id] = CachedEntry(
                url: cached.url,
                index: cached.index,
                accessTime: Date()
            )
            return cached.url
        }

        // Extract the entry
        return try await extractEntry(entry)
    }

    /// Get URL for entry by index
    func url(forIndex index: Int) async throws -> URL {
        guard index >= 0 && index < entries.count else {
            throw InkyPanelsError.reader(.invalidPageIndex(index))
        }
        return try await url(for: entries[index])
    }

    /// Check if an entry is already cached
    func isCached(_ entry: ArchiveEntry) -> Bool {
        extractedFiles[entry.id] != nil
    }

    /// Check if an index is already cached
    func isCached(index: Int) -> Bool {
        guard index >= 0 && index < entries.count else { return false }
        return isCached(entries[index])
    }

    /// Start two-tier prefetching around the given index
    /// - Tier 1: Immediately loads pages within immediateWindowSize concurrently
    /// - Tier 2: Background loads pages within backgroundWindowSize
    func prefetch(around index: Int) async {
        // Cancel any existing prefetch operation
        prefetchTask?.cancel()

        prefetchTask = Task {
            // Tier 1: Immediate window - load concurrently with high priority
            await prefetchImmediate(around: index)

            // Check for cancellation before starting background work
            guard !Task.isCancelled else { return }

            // Tier 2: Background window - load remaining pages with lower priority
            await prefetchBackground(around: index)
        }

        await prefetchTask?.value
    }

    /// Prefetch only immediate pages (for quick navigation response)
    func prefetchImmediate(around index: Int) async {
        let requests = buildImmediateRequests(around: index)

        // Extract concurrently using TaskGroup
        await withTaskGroup(of: Void.self) { group in
            var activeCount = 0

            for request in requests {
                // Skip if already cached or being extracted
                if extractedFiles[request.entry.id] != nil {
                    continue
                }

                // Limit concurrent extractions
                if activeCount >= maxConcurrentExtractions {
                    // Wait for one to complete before adding more
                    await group.next()
                    activeCount -= 1
                }

                group.addTask {
                    _ = try? await self.extractEntry(request.entry)
                }
                activeCount += 1
            }

            // Wait for all remaining tasks
            await group.waitForAll()
        }
    }

    /// Clear all cached files
    func clearAll() async {
        prefetchTask?.cancel()

        for cached in extractedFiles.values {
            try? FileManager.default.removeItem(at: cached.url)
        }
        extractedFiles.removeAll()
        extractingEntryIDs.removeAll()
    }

    /// Number of currently cached pages
    var cachedCount: Int {
        extractedFiles.count
    }

    // MARK: - Private Methods

    /// Extract a single entry and cache it
    private func extractEntry(_ entry: ArchiveEntry) async throws -> URL {
        // Check if already being extracted (avoid duplicate work)
        guard !extractingEntryIDs.contains(entry.id) else {
            // Wait a bit and check cache
            try? await Task.sleep(for: .milliseconds(50))
            if let cached = extractedFiles[entry.id] {
                return cached.url
            }
            // Still not ready, try extraction anyway
            return try await performExtraction(entry)
        }

        return try await performExtraction(entry)
    }

    private func performExtraction(_ entry: ArchiveEntry) async throws -> URL {
        extractingEntryIDs.insert(entry.id)
        defer { extractingEntryIDs.remove(entry.id) }

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

        // Evict old pages if over limit
        await evictIfNeeded(currentIndex: entry.index)

        return url
    }

    /// Build extraction requests for immediate window (sorted by distance from current)
    private func buildImmediateRequests(around index: Int) -> [ExtractionRequest] {
        var requests: [ExtractionRequest] = []

        // Current page first (highest priority)
        if index >= 0 && index < entries.count {
            requests.append(ExtractionRequest(entry: entries[index], priority: .immediate))
        }

        // Then expand outward in rings
        for offset in 1...immediateWindowSize {
            // Next page
            let nextIndex = index + offset
            if nextIndex < entries.count {
                requests.append(ExtractionRequest(entry: entries[nextIndex], priority: .high))
            }

            // Previous page
            let prevIndex = index - offset
            if prevIndex >= 0 {
                requests.append(ExtractionRequest(entry: entries[prevIndex], priority: .high))
            }
        }

        return requests
    }

    /// Prefetch background pages with lower priority
    private func prefetchBackground(around index: Int) async {
        // Build requests for pages outside immediate window but within background window
        var requests: [ExtractionRequest] = []

        for offset in (immediateWindowSize + 1)...backgroundWindowSize {
            guard !Task.isCancelled else { return }

            let nextIndex = index + offset
            if nextIndex < entries.count && extractedFiles[entries[nextIndex].id] == nil {
                requests.append(ExtractionRequest(entry: entries[nextIndex], priority: .background))
            }

            let prevIndex = index - offset
            if prevIndex >= 0 && extractedFiles[entries[prevIndex].id] == nil {
                requests.append(ExtractionRequest(entry: entries[prevIndex], priority: .background))
            }
        }

        // Extract with limited concurrency to avoid overwhelming the system
        // Use a smaller concurrent count for background work
        let backgroundConcurrency = max(1, maxConcurrentExtractions / 2)

        await withTaskGroup(of: Void.self) { group in
            var activeCount = 0

            for request in requests {
                guard !Task.isCancelled else { break }

                // Skip if already cached
                if extractedFiles[request.entry.id] != nil {
                    continue
                }

                if activeCount >= backgroundConcurrency {
                    await group.next()
                    activeCount -= 1
                }

                group.addTask {
                    // Add small delay between background extractions to reduce I/O pressure
                    try? await Task.sleep(for: .milliseconds(10))
                    _ = try? await self.extractEntry(request.entry)
                }
                activeCount += 1
            }

            await group.waitForAll()
        }
    }

    /// Evict oldest cached pages if over the limit
    private func evictIfNeeded(currentIndex: Int) async {
        guard extractedFiles.count > maxCachedPages else { return }

        // Sort by access time (oldest first) and distance from current page
        let sortedEntries = extractedFiles
            .sorted { entry1, entry2 in
                // Prioritize keeping pages near current index
                let dist1 = abs(entry1.value.index - currentIndex)
                let dist2 = abs(entry2.value.index - currentIndex)

                if dist1 != dist2 {
                    return dist1 > dist2 // Evict distant pages first
                }
                return entry1.value.accessTime < entry2.value.accessTime // Then by age
            }

        // Evict until under limit
        let toEvict = extractedFiles.count - maxCachedPages
        for (id, cached) in sortedEntries.prefix(toEvict) {
            try? FileManager.default.removeItem(at: cached.url)
            extractedFiles.removeValue(forKey: id)
        }
    }
}
