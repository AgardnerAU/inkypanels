import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

/// ViewModel for the comic reader
/// Uses streaming architecture - pages are extracted on-demand to temp files
@MainActor
@Observable
final class ReaderViewModel {

    // MARK: - Published State

    /// All page entries (metadata only, no image data)
    var entries: [ArchiveEntry] = []

    /// Currently displayed page index
    var currentPageIndex: Int = 0

    /// URL of current page image (extracted on demand)
    var currentPageURL: URL?

    /// URL of second page image for dual-page mode
    var secondPageURL: URL?

    /// Whether currently showing dual pages
    var isDualPageMode: Bool = false

    /// Whether current page is a wide spread (should show as single in dual mode)
    var isCurrentPageWideSpread: Bool = false

    /// Loading state
    var isLoading: Bool = true

    /// Error if loading failed
    var error: InkyPanelsError?

    /// Whether to show navigation controls
    var showControls: Bool = true

    /// Loading status message
    var loadingStatus: String = "Loading..."

    /// Extraction progress (0.0 to 1.0)
    var extractionProgress: Double = 0

    /// Whether the current page is bookmarked
    var isCurrentPageBookmarked: Bool = false

    /// All bookmarked pages for this comic
    var bookmarks: [Int] = []

    /// Reader settings (shared instance)
    let settings = ReaderSettings.shared

    // MARK: - Computed Properties

    /// Current entry (metadata)
    var currentEntry: ArchiveEntry? {
        guard currentPageIndex >= 0 && currentPageIndex < entries.count else { return nil }
        return entries[currentPageIndex]
    }

    /// Second entry for dual-page mode
    var secondEntry: ArchiveEntry? {
        guard isDualPageMode && !isCurrentPageWideSpread else { return nil }
        let secondIndex = currentPageIndex + 1
        guard secondIndex < entries.count else { return nil }
        return entries[secondIndex]
    }

    var totalPages: Int {
        entries.count
    }

    var canGoNext: Bool {
        currentPageIndex < entries.count - 1
    }

    var canGoPrevious: Bool {
        currentPageIndex > 0
    }

    var progressPercentage: Double {
        guard totalPages > 0 else { return 0 }
        return Double(currentPageIndex + 1) / Double(totalPages) * 100
    }

    /// Number of pages to advance (1 for single, 2 for dual unless at end or wide spread)
    private var pageAdvanceCount: Int {
        if isDualPageMode && !isCurrentPageWideSpread && currentPageIndex + 2 < entries.count {
            return 2
        }
        return 1
    }

    // MARK: - Private Properties

    private let comic: ComicFile
    private var reader: (any ArchiveReader)?
    private let extractionCache: ExtractionCache
    private var progressService: ProgressService?

    // MARK: - Initialization

    init(comic: ComicFile, extractionCache: ExtractionCache = ExtractionCache()) {
        self.comic = comic
        self.extractionCache = extractionCache
    }

    /// Configure progress service (call from view with modelContext)
    func configureProgressService(modelContext: ModelContext) {
        self.progressService = ProgressService(modelContext: modelContext)
    }

    // MARK: - Public Methods

    /// Load the comic and prepare for reading
    func loadComic() async {
        isLoading = true
        error = nil
        loadingStatus = "Opening \(comic.name)..."
        extractionProgress = 0

        do {
            // Create appropriate reader for this format
            loadingStatus = "Preparing reader..."
            extractionProgress = 0.1

            reader = try ArchiveReaderFactory.reader(for: comic.url)

            // Get entry list (metadata only, fast)
            loadingStatus = "Reading archive..."
            extractionProgress = 0.3

            entries = try await reader!.listEntries()

            loadingStatus = "Found \(entries.count) pages"
            extractionProgress = 0.6

            // Configure cache with reader and entries
            await extractionCache.configure(reader: reader!, entries: entries)

            // Restore last reading position and bookmarks if available
            if let savedProgress = await progressService?.loadProgress(for: comic.url.path) {
                currentPageIndex = min(savedProgress.currentPage, entries.count - 1)
                bookmarks = savedProgress.bookmarks
                isCurrentPageBookmarked = bookmarks.contains(currentPageIndex)
            }

            // Extract current page and immediate neighbors concurrently
            loadingStatus = "Loading pages..."
            extractionProgress = 0.8

            // Start immediate prefetch (current page + neighbors) - this is fast
            await extractionCache.prefetchImmediate(around: currentPageIndex)

            // Now load the current page URL (should be instant since we just prefetched)
            await loadCurrentPage()

            // Save progress immediately so file appears in Recent tab
            saveProgress()

            extractionProgress = 1.0
        } catch let err as InkyPanelsError {
            error = err
        } catch {
            self.error = .archive(.extractionFailed(underlying: error))
        }

        isLoading = false
    }

    func goToNextPage() {
        guard canGoNext else { return }
        currentPageIndex += pageAdvanceCount
        // Clamp to valid range
        currentPageIndex = min(currentPageIndex, entries.count - 1)
        Task { await loadCurrentPage() }
        saveProgress()
        updateBookmarkState()
    }

    func goToPreviousPage() {
        guard canGoPrevious else { return }
        // Go back by pageAdvanceCount, but check if previous page was a wide spread
        let previousIndex = max(0, currentPageIndex - pageAdvanceCount)
        currentPageIndex = previousIndex
        Task { await loadCurrentPage() }
        saveProgress()
        updateBookmarkState()
    }

    func goToPage(_ index: Int) {
        guard index >= 0 && index < entries.count else { return }
        currentPageIndex = index
        Task { await loadCurrentPage() }
        saveProgress()
        updateBookmarkState()
    }

    /// Update page layout based on current orientation
    func updateLayoutForOrientation(isLandscape: Bool) {
        // Update settings with current orientation
        settings.isLandscape = isLandscape

        // Get the layout for current orientation
        let newDualMode = settings.currentLayout == .dual

        if newDualMode != isDualPageMode {
            isDualPageMode = newDualMode
            Task { await loadCurrentPage() }
        }
    }

    func toggleControls() {
        withAnimation(.easeInOut(duration: Constants.Reader.controlsFadeDuration)) {
            showControls.toggle()
        }
    }

    func handleTap(at location: CGPoint, in size: CGSize) {
        let tapZoneWidth = size.width * Constants.Reader.tapZoneWidth

        if location.x < tapZoneWidth {
            goToPreviousPage()
        } else if location.x > size.width - tapZoneWidth {
            goToNextPage()
        } else {
            toggleControls()
        }
    }

    func handleSwipe(translation: CGFloat) {
        if translation < -Constants.Reader.swipeThreshold {
            goToNextPage()
        } else if translation > Constants.Reader.swipeThreshold {
            goToPreviousPage()
        }
    }

    /// Cleanup when done reading
    func cleanup() async {
        await extractionCache.clearAll()
    }

    // MARK: - Private Methods

    private func loadCurrentPage() async {
        guard let entry = currentEntry else {
            currentPageURL = nil
            secondPageURL = nil
            return
        }

        do {
            // Load current page - this will be fast if already cached
            currentPageURL = try await extractionCache.url(for: entry)

            // Check if current page is a wide spread (smart detection)
            if isDualPageMode && settings.smartSpreadDetection {
                isCurrentPageWideSpread = await checkIfWideSpread(url: currentPageURL)
            } else {
                isCurrentPageWideSpread = false
            }

            // Load second page if in dual mode and not a wide spread
            if isDualPageMode && !isCurrentPageWideSpread, let secondEntry = secondEntry {
                secondPageURL = try await extractionCache.url(for: secondEntry)
            } else {
                secondPageURL = nil
            }

            // Start two-tier prefetch in background (non-blocking)
            // Tier 1: Immediate neighbors loaded quickly
            // Tier 2: Larger window loaded progressively in background
            Task.detached(priority: .utility) { [extractionCache, currentPageIndex] in
                await extractionCache.prefetch(around: currentPageIndex)
            }
        } catch {
            // Failed to load page - keep previous URL or show placeholder
            currentPageURL = nil
            secondPageURL = nil
        }
    }

    /// Check if an image is a wide spread (width > height * 1.2)
    private func checkIfWideSpread(url: URL?) async -> Bool {
        guard let url = url else { return false }

        #if canImport(UIKit)
        guard let image = UIImage(contentsOfFile: url.path) else { return false }
        let size = image.size
        return size.width > size.height * 1.2
        #else
        return false
        #endif
    }

    private func saveProgress() {
        Task {
            await progressService?.saveProgress(
                for: comic.url.path,
                currentPage: currentPageIndex,
                totalPages: entries.count
            )
        }
    }

    private func updateBookmarkState() {
        Task {
            isCurrentPageBookmarked = await progressService?.isBookmarked(
                for: comic.url.path,
                page: currentPageIndex
            ) ?? false
        }
    }

    /// Toggle bookmark for the current page
    func toggleBookmark() {
        Task {
            await progressService?.toggleBookmark(for: comic.url.path, at: currentPageIndex)
            isCurrentPageBookmarked.toggle()
            await loadBookmarks()
        }
    }

    /// Load all bookmarks for this comic
    private func loadBookmarks() async {
        bookmarks = await progressService?.bookmarks(for: comic.url.path) ?? []
    }
}
