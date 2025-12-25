import SwiftUI

/// ViewModel for the comic reader
@MainActor
@Observable
final class ReaderViewModel {

    // MARK: - Published State

    var pages: [ComicPage] = []
    var currentPageIndex: Int = 0
    var isLoading: Bool = true
    var error: InkyPanelsError?
    var showControls: Bool = true

    // MARK: - Computed Properties

    var currentPage: ComicPage? {
        guard currentPageIndex >= 0 && currentPageIndex < pages.count else { return nil }
        return pages[currentPageIndex]
    }

    var totalPages: Int {
        pages.count
    }

    var canGoNext: Bool {
        currentPageIndex < pages.count - 1
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
    private let archiveService: ArchiveService

    // Cache window: keep current page ± 3 in memory
    private let cacheWindow = 3

    // MARK: - Initialization

    init(comic: ComicFile, archiveService: ArchiveService = ArchiveService()) {
        self.comic = comic
        self.archiveService = archiveService
    }

    // MARK: - Public Methods

    func loadComic() async {
        isLoading = true
        error = nil

        do {
            pages = try await archiveService.extractPages(from: comic.url)

            // Restore last reading position if available
            if let progress = comic.readingProgress {
                currentPageIndex = min(progress.currentPage, pages.count - 1)
            }
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
        saveProgress()
    }

    func goToPreviousPage() {
        guard canGoPrevious else { return }
        currentPageIndex -= 1
        saveProgress()
    }

    func goToPage(_ index: Int) {
        guard index >= 0 && index < pages.count else { return }
        currentPageIndex = index
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
            // Left zone: previous page
            goToPreviousPage()
        } else if location.x > size.width - tapZoneWidth {
            // Right zone: next page
            goToNextPage()
        } else {
            // Center zone: toggle controls
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

    // MARK: - Private Methods

    private func saveProgress() {
        // TODO: Save to ProgressService
        // For now, just update the in-memory state
    }
}
