import SwiftUI

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

    // MARK: - Computed Properties

    /// Current entry (metadata)
    var currentEntry: ArchiveEntry? {
        guard currentPageIndex >= 0 && currentPageIndex < entries.count else { return nil }
        return entries[currentPageIndex]
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

    // MARK: - Private Properties

    private let comic: ComicFile
    private var reader: (any ArchiveReader)?
    private let extractionCache: ExtractionCache

    /// Prefetch window size
    private let prefetchWindow = 3

    // MARK: - Initialization

    init(comic: ComicFile, extractionCache: ExtractionCache = ExtractionCache()) {
        self.comic = comic
        self.extractionCache = extractionCache
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

            // Restore last reading position if available
            if let progress = comic.readingProgress {
                currentPageIndex = min(progress.currentPage, entries.count - 1)
            }

            // Extract current page
            loadingStatus = "Loading first page..."
            extractionProgress = 0.8

            await loadCurrentPage()

            // Prefetch nearby pages in background
            Task {
                await extractionCache.prefetch(around: currentPageIndex)
            }

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
        currentPageIndex += 1
        Task { await loadCurrentPage() }
        saveProgress()
    }

    func goToPreviousPage() {
        guard canGoPrevious else { return }
        currentPageIndex -= 1
        Task { await loadCurrentPage() }
        saveProgress()
    }

    func goToPage(_ index: Int) {
        guard index >= 0 && index < entries.count else { return }
        currentPageIndex = index
        Task { await loadCurrentPage() }
        saveProgress()
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
            return
        }

        do {
            currentPageURL = try await extractionCache.url(for: entry)

            // Prefetch nearby pages
            Task {
                await extractionCache.prefetch(around: currentPageIndex)
            }
        } catch {
            // Failed to load page - keep previous URL or show placeholder
            currentPageURL = nil
        }
    }

    private func saveProgress() {
        // TODO: Save to ProgressService
    }
}
