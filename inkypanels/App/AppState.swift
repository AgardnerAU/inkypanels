import SwiftUI

/// Central observable state for the application.
/// Single source of truth for cross-cutting concerns.
@Observable
final class AppState {
    /// Shared instance for global access
    static let shared = AppState()

    /// All comic files in the library
    var libraryFiles: [ComicFile] = []

    /// Recently opened files
    var recentFiles: [ComicFile] = []

    /// Whether the secure vault is currently unlocked
    var isVaultUnlocked: Bool = false

    /// Current active reading session, if any
    var currentReadingSession: ReadingSession?

    /// Global loading state for async operations
    var isLoading: Bool = false

    /// Global error for display
    var currentError: InkyPanelsError?

    /// File opened from external source (Files app, Share sheet, etc.)
    var openedFileURL: URL?

    /// Comic file to open immediately (created from openedFileURL)
    var fileToOpen: ComicFile?
}

/// Represents an active reading session
struct ReadingSession {
    let comic: ComicFile
    var currentPage: Int
    let totalPages: Int
    let startedAt: Date
}
