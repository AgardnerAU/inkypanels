import Foundation
import CoreGraphics

/// App-wide constants
enum Constants {
    /// App metadata
    enum App {
        static let name = "Inky Panels Comic Reader"
        static let version = "0.1.0"
        static let bundleIdentifier = "com.inkypanels.app"
    }

    /// File system paths
    enum Paths {
        static let comicsFolder = "Comics"
        static let vaultFolder = ".vault"
        static let vaultFilesFolder = "files"
        static let vaultManifest = "manifest.encrypted"
        static let thumbnailsFolder = "Thumbnails"
    }

    /// Cache settings
    enum Cache {
        static let maxPagesInMemory = 7
        static let prefetchPageCount = 3
        static let thumbnailCacheSizeLimit: Int64 = 500 * 1024 * 1024 // 500MB
        static let defaultThumbnailSize = CGSize(width: 200, height: 280)

        // Two-tier page caching
        /// Pages to load immediately with high priority (current ± this value)
        static let immediateWindowSize = 2
        /// Pages to load in background (current ± this value)
        static let backgroundWindowSize = 10
        /// Maximum concurrent page extractions
        static let maxConcurrentExtractions = 4
        /// Total pages to keep in cache before eviction
        static let maxCachedPages = 25
    }

    /// Security settings
    enum Security {
        static let pbkdf2Iterations = 600_000
        static let saltLength = 32
        static let keychainService = "com.inkypanels.vault"
    }

    /// Reader settings
    enum Reader {
        static let tapZoneWidth: CGFloat = 0.25 // 25% of screen width
        static let swipeThreshold: CGFloat = 50
        static let controlsFadeDuration: TimeInterval = 0.2
        static let autoHideControlsDelay: TimeInterval = 3.0
    }

    /// UserDefaults keys
    enum UserDefaultsKey {
        static let lastOpenedFile = "lastOpenedFile"
        static let defaultFitMode = "defaultFitMode"
        static let readingDirection = "readingDirection"
        static let showPageNumbers = "showPageNumbers"
        static let autoHideControls = "autoHideControls"
        static let recentFilesLimit = "recentFilesLimit"
        static let thumbnailSize = "thumbnailSize"
        static let showRecentFiles = "showRecentFiles"
        static let hideVaultFromRecent = "hideVaultFromRecent"
        static let autoHideSidebar = "autoHideSidebar"
        static let clearRecentOnExit = "clearRecentOnExit"
        static let hideVaultFromSidebar = "hideVaultFromSidebar"
    }
}
