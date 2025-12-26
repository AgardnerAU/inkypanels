# inkypanels - Architecture Decisions Record

This document captures architectural decisions for the inkypanels project.

> **Last Updated**: 2025-12-26
> **Status**: Phase 1C + Library Features complete. Phase 1D (Secure Vault) next.

---

## Development Progress

| Phase | Status | Notes |
|-------|--------|-------|
| Phase 0: Foundation | Complete | Project structure, models, protocols |
| Phase 0.1: Walking Skeleton | Complete | FileService, basic reader, navigation |
| Phase 1B: Archive Support | Complete | PDF, streaming extraction, security |
| Phase 1C: Reader Experience | Complete | Zoom, pan, progress persistence, bookmarks |
| Library Features | Complete | Thumbnails, favourites, recent files, bulk delete, settings |
| Phase 1D: Secure Vault | Not Started | Encryption, biometrics |

---

## 1. Dependency Injection Strategy

**Decision**: Constructor Injection with Factory Pattern

**Details**:
- Services instantiated directly in ViewModels with default parameters
- Factory (`ArchiveReaderFactory`) routes to appropriate backend by file type
- Tests inject mock implementations via constructor

**Example**:
```swift
// Factory creates appropriate reader based on file type
let reader = try ArchiveReaderFactory.reader(for: comic.url)
let entries = try await reader.listEntries()

// ViewModel with injectable dependencies
init(comic: ComicFile, extractionCache: ExtractionCache = ExtractionCache()) {
    self.comic = comic
    self.extractionCache = extractionCache
}
```

---

## 2. Error Handling

**Decision**: Typed Error Enum Hierarchy

**Structure**:
```swift
enum InkyPanelsError: Error, LocalizedError {
    case archive(ArchiveError)
    case vault(VaultError)
    case fileSystem(FileSystemError)
    case reader(ReaderError)

    var errorDescription: String? { ... }
}

enum ArchiveError: Error {
    case unsupportedFormat(String)
    case rar5NotSupported
    case corruptedArchive
    case extractionFailed(underlying: Error)
    case passwordProtected
    case emptyArchive
}

enum VaultError: Error {
    case incorrectPassword
    case biometricFailed
    case encryptionFailed(underlying: Error)
    case decryptionFailed(underlying: Error)
    case manifestCorrupted
}

enum FileSystemError: Error {
    case fileNotFound(URL)
    case permissionDenied(URL)
    case insufficientStorage
    case deletionFailed(underlying: Error)
}

enum ReaderError: Error {
    case pageLoadFailed(index: Int)
    case unsupportedImageFormat
    case imageTooLarge
}
```

---

## 3. Concurrency Model

**Decision**: Actor-Based Services with On-Demand Extraction

**Details**:
- All readers and cache services are Swift actors
- Pages extracted on-demand to temp files (not loaded into memory upfront)
- ExtractionCache manages temp file lifecycle with windowed eviction
- ViewModels marked `@MainActor` for UI updates
- Async/await throughout (no completion handlers)

**Example**:
```swift
actor ZIPFoundationReader: ArchiveReader {
    func listEntries() async throws -> [ArchiveEntry] {
        // Returns metadata only - no decompression yet
    }

    func extractEntry(_ entry: ArchiveEntry) async throws -> URL {
        // Extracts single entry to temp file, returns URL
    }
}

actor ExtractionCache {
    func url(for entry: ArchiveEntry) async throws -> URL {
        // Returns cached URL or extracts on-demand
    }
}

@MainActor
@Observable
final class ReaderViewModel {
    func loadComic() async {
        reader = try ArchiveReaderFactory.reader(for: comic.url)
        entries = try await reader.listEntries()  // Fast: metadata only
        await loadCurrentPage()  // Extract just current page
    }

    private func loadCurrentPage() async {
        currentPageURL = try await extractionCache.url(for: currentEntry)
    }
}
```

---

## 4. State Communication

**Decision**: Shared Observable State (AppState)

**Details**:
- Central `AppState` class holds cross-cutting state
- Single source of truth for library, vault status, current session
- ViewModels read from AppState, services mutate it
- Unidirectional data flow

**Structure**:
```swift
@Observable
final class AppState {
    var libraryFiles: [ComicFile] = []
    var recentFiles: [ComicFile] = []
    var isVaultUnlocked: Bool = false
    var currentReadingSession: ReadingSession?
    var thumbnailCache: ThumbnailCache
}
```

---

## 5. Release Phases

**Decision**: Iterative Releases

| Version | Features | Risk Level | Status |
|---------|----------|------------|--------|
| **v0.1** | File browser, CBZ/PDF, basic navigation, streaming extraction | Low | **Done** |
| **v0.2** | ZoomableImageView (pinch/pan), reading controls, progress persistence | Medium | **Done** |
| **v0.2.1** | Thumbnails, favourites, recent files, bulk delete, image/folder readers, settings | Medium | **Done** |
| **v0.3** | libarchive XCFramework for CBR/CB7, RAR5 detection | High | Blocked on build |
| **v0.4** | Secure vault with AES-256 encryption | High | **Next** |

**Rationale**: De-risk by getting core reading working before tackling C bridging and encryption.

**Note**: PDF support moved to v0.1 (uses native PDFKit). libarchive integration prepared with feature flag (`LIBARCHIVE_ENABLED`) but requires building the XCFramework.

---

## 6. Vault Security Parameters

### Key Derivation
- **Algorithm**: PBKDF2-SHA256
- **Iterations**: 600,000
- **Salt**: 32 bytes, randomly generated per vault, stored alongside encrypted data

### Encryption
- **Algorithm**: AES-256-GCM (via CryptoKit)
- **Nonce**: 12 bytes, randomly generated per file
- **Authentication Tag**: 16 bytes (built into GCM)

### Timeout Behaviour
- **Lock Trigger**: Immediately when app enters background
- **Implementation**: Monitor `scenePhase` for `.background` transition

### Biometric Fallback
- **Behaviour**: Immediate password fallback on any biometric failure
- **Flow**: Face ID prompt → Cancel/Fail → Password entry shown

---

## 7. Memory Management

### Streaming Extraction (Implemented)
- **Strategy**: Extract to temp files on-demand, not memory
- **Cache Location**: `tmp/inkypanels-extraction/[archive-hash]/`
- **Window Size**: Current page ± 5 pages kept extracted
- **Prefetch**: Extract next 5 pages in background on navigation
- **Eviction**: Delete temp files outside 2x window on navigation
- **Cleanup**: All temp files deleted when reader closes

### Page Display
- **Loading**: `UIImage(contentsOfFile:)` from temp file URL
- **Memory**: Only current page image in memory at a time
- **Benefit**: Large comics (1000+ pages) work without OOM

### Thumbnail Cache (Implemented)
- **Location**: `Caches/Thumbnails/`
- **Naming**: SHA-256 hash of file path (64 chars)
- **Size**: 200x280 pixels (configurable in Constants)
- **Generation**: Background task on library load
- **Memory Cache**: In-memory LRU for recently accessed

---

## 8. Accessibility

**Decision**: Core Accessibility from Day 1

**Requirements**:
- `.accessibilityLabel()` on all interactive elements
- `.accessibilityHint()` for non-obvious actions
- Dynamic Type support (use system fonts with `.font(.body)` etc.)
- Sufficient colour contrast (WCAG AA minimum)
- Test with VoiceOver during development

---

## 9. iPad Multitasking

**Decision**: Responsive Layout

**Implementation**:
- `NavigationSplitView` adapts automatically to size class
- Sidebar collapses in compact horizontal size class
- Reader content scales appropriately for window size
- Use `@Environment(\.horizontalSizeClass)` for layout decisions

---

## 10. State Restoration

**Decision**: No Automatic Restoration

**Behaviour**:
- App always opens to Library view
- Reading progress saved per-comic in SwiftData
- User navigates to comic and resumes from last saved position

**Rationale**: Simpler implementation, predictable behaviour.

---

## 11. View Testing

**Decision**: Preview-Driven Development + Snapshot Tests

**Tools**:
- SwiftUI Previews for development iteration
- [swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing) for regression detection

**Approach**:
- Create previews for all views with various states (loading, error, empty, populated)
- Snapshot tests capture preview images as references
- CI fails if views change unexpectedly

---

## 12. File Conflict Handling

**Decision**: Auto-Rename with Duplicate Cleanup Feature

**Import Behaviour**:
- Automatically rename to `filename (1).cbz`, `filename (2).cbz`, etc.
- No user interruption during import

**Library Feature** (Phase 2):
- "Find Duplicates" action identifies files with `(n)` suffixes
- User can review and bulk-delete duplicates

---

## 13. Dependencies

### Swift Packages

| Package | Purpose | Version | Status |
|---------|---------|---------|--------|
| [ZIPFoundation](https://github.com/weichsel/ZIPFoundation) | CBZ/ZIP extraction | 0.9+ | Active |
| [swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing) | View regression tests | 1.15+ | Active |

### Future (v0.3+)

| Package | Purpose | Status |
|---------|---------|--------|
| libarchive XCFramework | CBR/CB7 extraction | Infrastructure ready, build pending |

---

## 14. Streaming Extraction Architecture

**Decision**: Extract-on-Demand to Temp Files

**Date**: 2024-12-26

**Context**: Original design loaded all pages into memory as `Data` arrays. This would fail for large comics (1000+ pages) and waste memory for pages never viewed.

**Decision**:
- `ArchiveReader` protocol returns `[ArchiveEntry]` (metadata only)
- `extractEntry()` writes to temp file, returns `URL`
- `ExtractionCache` manages temp file lifecycle
- PageView loads image from file URL

**Consequences**:
- Comics of any size work without OOM
- Slightly slower page transitions (disk I/O)
- Temp files cleaned up on reader close
- More complex but more robust

---

## 15. Archive Security Hardening

**Decision**: Validate All Archive Entries Before Extraction

**Date**: 2024-12-26

**Context**: Archives can contain malicious content (zip bombs, path traversal attacks, oversized files).

**Implementation** (`ArchiveLimits`):
```swift
enum ArchiveLimits {
    static let maxEntryCount = 2000
    static let maxUncompressedEntrySize: UInt64 = 100 * 1024 * 1024  // 100MB
    static let maxTotalUncompressedSize: UInt64 = 2 * 1024 * 1024 * 1024  // 2GB
    static let allowedExtensions: Set<String> = ["jpg", "jpeg", "png", ...]
}
```

**Validations**:
- Reject paths containing `..` (directory traversal)
- Reject absolute paths starting with `/`
- Skip entries exceeding size limits
- Only extract whitelisted image extensions
- Skip `__MACOSX`, hidden files, `_` prefixed files

---

## 16. Build-Time Feature Flags

**Decision**: Use Compile-Time Flags for Optional Features

**Date**: 2024-12-26

**Context**: libarchive requires building a C library as an XCFramework. Until that's done, CBR/CB7 support should gracefully degrade.

**Implementation**:
```swift
#if LIBARCHIVE_ENABLED
actor LibArchiveReader: ArchiveReader {
    // Real implementation
}
#else
actor LibArchiveReader: ArchiveReader {
    func listEntries() async throws -> [ArchiveEntry] {
        throw InkyPanelsError.archive(.unsupportedFormat("RAR/7z"))
    }
}
#endif
```

**Configuration** (project.yml):
```yaml
settings:
  configs:
    Debug-LibArchive:
      SWIFT_ACTIVE_COMPILATION_CONDITIONS: DEBUG LIBARCHIVE_ENABLED
```

**Benefits**:
- CI passes without libarchive dependency
- Clean v0.1 release with CBZ/PDF only
- Easy to enable for TestFlight/internal builds

---

## 17. SHA256 for Filesystem-Safe Identifiers

**Decision**: Use SHA256 Hash Instead of Base64 for IDs

**Date**: 2025-12-26

**Context**: Original implementation used Base64 encoding of file paths for `ArchiveEntry.id` and cache directory names. This caused "Invalid filename" errors when paths exceeded the 255-byte filesystem limit after Base64 encoding (which increases size by ~33%).

**Decision**:
- Use SHA256 hash of file path for `ArchiveEntry.id` (64 chars, always valid)
- Use SHA256 hash for cache directory names in `ZIPFoundationReader`, `PDFReader`
- SHA256 output is hexadecimal, filesystem-safe, and fixed-length

**Implementation**:
```swift
import CryptoKit

let hash = SHA256.hash(data: Data(path.utf8))
let id = hash.compactMap { String(format: "%02x", $0) }.joined()
// Always 64 characters, e.g., "a1b2c3d4..."
```

**Consequences**:
- No filename length errors regardless of path length
- Cache directories named by hash, not encoded path
- Slight computational overhead (negligible)

---

## 18. ImageReader and FolderReader for Non-Archive Sources

**Decision**: Extend ArchiveReader Protocol to Handle Images and Folders

**Date**: 2025-12-26

**Context**: Users wanted to open single image files and folders of images directly, not just archives. The existing `ArchiveReaderFactory` only handled CBZ, PDF, and archive formats.

**Decision**:
- `ImageReader`: Treats single image file as 1-page "archive"
- `FolderReader`: Lists images in folder as multi-page "archive", sorted naturally
- Both conform to `ArchiveReader` protocol for seamless integration

**Implementation**:
```swift
actor ImageReader: ArchiveReader {
    func listEntries() async throws -> [ArchiveEntry] {
        // Single entry with image filename
    }
    func extractEntry(_ entry: ArchiveEntry) async throws -> URL {
        return archiveURL  // Return original file, no extraction needed
    }
}

actor FolderReader: ArchiveReader {
    func listEntries() async throws -> [ArchiveEntry] {
        // List all images in folder, sorted by filename
    }
    func extractEntry(_ entry: ArchiveEntry) async throws -> URL {
        return archiveURL.appendingPathComponent(entry.path)
    }
}
```

**Factory Routing**:
```swift
// Check for directory first
if isDirectory { return FolderReader(url: url) }

// Check for image extensions
case "jpg", "png", ...: return ImageReader(url: url)
```

**Consequences**:
- Unified reading experience for all content types
- No special-casing in ReaderView or ReaderViewModel
- Natural sorting for folder contents (handles "page 2" vs "page 10" correctly)

---

## 19. ThumbnailService with Background Generation

**Decision**: Actor-Based Thumbnail Service with Disk Caching

**Date**: 2025-12-26

**Context**: Library needed cover thumbnails for visual browsing. Generating thumbnails on-demand would cause visible delays; pre-generating all thumbnails would slow app launch.

**Decision**:
- `ThumbnailService` actor generates thumbnails in background after library loads
- Thumbnails cached to disk (`Caches/Thumbnails/`) using SHA256 filename
- Memory cache for recently accessed thumbnails
- `ThumbnailView` displays placeholder until thumbnail ready

**Implementation**:
```swift
actor ThumbnailService: ThumbnailServiceProtocol {
    private var memoryCache: [String: Data] = [:]
    private let cacheDirectory: URL  // Caches/Thumbnails/

    func thumbnail(for file: ComicFile) async throws -> Data {
        // Check memory cache → disk cache → generate
    }

    func generateInBackground(files: [ComicFile]) async {
        // Process files not in cache
    }
}
```

**Trigger** (in `LibraryViewModel.loadFiles()`):
```swift
ThumbnailView.generateThumbnailsInBackground(for: files)
```

**Consequences**:
- Fast library display (placeholders shown immediately)
- Thumbnails appear as they're generated
- Persistent cache survives app restarts
- Memory-efficient (disk-backed with small memory cache)

---

## 20. Favourites Using SwiftData

**Decision**: SwiftData Model for Favourite Persistence

**Date**: 2025-12-26

**Context**: Users wanted to mark files as favourites with swipe gesture. Needed persistent storage that integrates with existing SwiftData usage.

**Decision**:
- `FavouriteRecord` SwiftData model with unique `filePath` constraint
- `FavouriteService` for CRUD operations
- Swipe-right gesture in LibraryView to toggle
- Star indicator on favourite files

**Implementation**:
```swift
@Model
final class FavouriteRecord {
    @Attribute(.unique) var filePath: String
    var addedDate: Date
}

@MainActor
final class FavouriteService {
    func toggleFavourite(filePath: String) async
    func favouriteStatus(for filePaths: [String]) async -> Set<String>
}
```

**View Integration**:
```swift
.swipeActions(edge: .leading) {
    Button { await viewModel.toggleFavourite(file) }
    label: { Label("Favourite", systemImage: "star.fill") }
    .tint(.yellow)
}
```

**Consequences**:
- Favourites persist across app restarts
- Batch status query for efficient UI updates
- Uses existing SwiftData container (no migration needed)

---

## 21. Recent Files with Settings Control

**Decision**: Query-Based Recent Files with User Settings

**Date**: 2025-12-26

**Context**: Users wanted to see recently read files. Settings needed to control visibility and filter vault files.

**Decision**:
- Query `ProgressRecord` sorted by `lastReadDate` descending
- Settings toggle to hide Recent tab entirely
- Settings toggle to filter vault files from recent list
- `RecentFilesViewModel` handles query and file existence checks

**Implementation**:
```swift
// ProgressService
func recentFiles(limit: Int = 20) async -> [ProgressRecord] {
    var descriptor = FetchDescriptor<ProgressRecord>(
        sortBy: [SortDescriptor(\ProgressRecord.lastReadDate, order: .reverse)]
    )
    descriptor.fetchLimit = limit
    return try modelContext.fetch(descriptor)
}

// RecentFilesViewModel
func loadRecentFiles() async {
    let hideVaultFiles = UserDefaults.standard.bool(forKey: hideVaultFromRecentKey)
    for record in records {
        if hideVaultFiles && record.filePath.contains("/.vault/") { continue }
        if !FileManager.default.fileExists(atPath: record.filePath) { continue }
        // Add to list
    }
}
```

**Settings** (ContentView):
```swift
@AppStorage("showRecentFiles") var showRecentFiles = true
@AppStorage("hideVaultFromRecent") var hideVaultFromRecent = false
```

**Consequences**:
- No additional data model needed (reuses ProgressRecord)
- Gracefully handles deleted files (filters non-existent)
- User control over privacy-sensitive recent list

---

## Service Protocol Definitions

### Core Protocols (Implemented)

```swift
// MARK: - Archive Reader (NEW - Streaming Architecture)

protocol ArchiveReader: AnyObject, Sendable {
    var archiveURL: URL { get }
    func listEntries() async throws -> [ArchiveEntry]
    func extractEntry(_ entry: ArchiveEntry) async throws -> URL
    static func canOpen(_ url: URL) -> Bool
}

struct ArchiveEntry: Identifiable, Sendable {
    let id: String              // Unique within archive
    let path: String            // Original path in archive
    let fileName: String        // Just the filename
    let uncompressedSize: UInt64
    let index: Int              // Sorted position for page ordering
}

// Implementations:
// - ZIPFoundationReader (CBZ, ZIP)
// - PDFReader (PDF)
// - LibArchiveReader (CBR, CB7, RAR, 7z) - requires LIBARCHIVE_ENABLED

// MARK: - File Service

protocol FileServiceProtocol: Sendable {
    func listFiles(in directory: URL) async throws -> [ComicFile]
    func fileExists(at url: URL) -> Bool
    func moveFile(from source: URL, to destination: URL) async throws
    func deleteFile(at url: URL) async throws
    func detectFileType(at url: URL) async throws -> ComicFileType
}
```

### Implemented Protocols (v0.3)

```swift
// MARK: - Progress Service (Implemented in Phase 1C)

@MainActor
protocol ProgressServiceProtocol: Sendable {
    func saveProgress(for filePath: String, currentPage: Int, totalPages: Int) async
    func loadProgress(for filePath: String) async -> ProgressRecord?
    func toggleBookmark(for filePath: String, at page: Int) async
    func isBookmarked(for filePath: String, page: Int) async -> Bool
    func bookmarks(for filePath: String) async -> [Int]
    func deleteProgress(for filePath: String) async
}

// SwiftData Model
@Model
final class ProgressRecord {
    @Attribute(.unique) var filePath: String
    var currentPage: Int
    var totalPages: Int
    var lastReadDate: Date
    var isCompleted: Bool
    var bookmarks: [Int]
}
```

### Implemented Protocols (Library Features)

```swift
// MARK: - Thumbnail Service (Implemented)

protocol ThumbnailServiceProtocol: Sendable {
    func thumbnail(for file: ComicFile) async throws -> Data
    func generateInBackground(files: [ComicFile]) async
    func clearCache() async
}

// MARK: - Favourite Service (Implemented)

@MainActor
final class FavouriteService {
    func isFavourite(filePath: String) async -> Bool
    func toggleFavourite(filePath: String) async
    func favouriteStatus(for filePaths: [String]) async -> Set<String>
    func allFavourites() async -> [String]
}
```

### Vault Protocols (v0.4)

```swift
// MARK: - Encryption Service

protocol EncryptionServiceProtocol: Sendable {
    func encrypt(data: Data, withKey key: SymmetricKey) async throws -> Data
    func decrypt(data: Data, withKey key: SymmetricKey) async throws -> Data
    func deriveKey(from password: String, salt: Data) async throws -> SymmetricKey
}

// MARK: - Keychain Service

protocol KeychainServiceProtocol: Sendable {
    func save(_ data: Data, for key: String, requireBiometric: Bool) async throws
    func retrieve(for key: String, prompt: String) async throws -> Data?
    func delete(for key: String) async throws
}

// MARK: - Vault Service

protocol VaultServiceProtocol: Sendable {
    func unlock(withPassword password: String) async throws
    func unlockWithBiometric() async throws
    func lock()
    var isUnlocked: Bool { get }
    func addFile(_ file: ComicFile) async throws
    func removeFile(_ file: VaultItem) async throws
    func listFiles() async throws -> [VaultItem]
}
```

---

## Directory Structure (Current)

```
inkypanels/
├── inkypanels.xcodeproj
├── project.yml                          # XcodeGen configuration
├── Package.swift                        # SPM manifest
├── inkypanels/
│   ├── App/
│   │   ├── InkyPanelsApp.swift          # SwiftData container setup
│   │   ├── ContentView.swift            # Root navigation + RecentFilesView + SettingsView
│   │   └── AppState.swift
│   │
│   ├── Models/
│   │   ├── ComicFile.swift              # ComicFile + ComicFileType
│   │   ├── ComicPage.swift              # Legacy (being phased out)
│   │   ├── ArchiveEntry.swift           # Page metadata (SHA256 ID)
│   │   ├── ProgressRecord.swift         # SwiftData progress persistence
│   │   ├── FavouriteRecord.swift        # SwiftData favourites
│   │   ├── ReadingProgress.swift
│   │   ├── VaultItem.swift
│   │   └── Errors/
│   │       ├── InkyPanelsError.swift
│   │       ├── ArchiveError.swift
│   │       ├── VaultError.swift
│   │       ├── FileSystemError.swift
│   │       └── ReaderError.swift
│   │
│   ├── Protocols/
│   │   ├── ArchiveReader.swift          # Streaming extraction
│   │   ├── FileServiceProtocol.swift
│   │   ├── ProgressServiceProtocol.swift
│   │   ├── ThumbnailServiceProtocol.swift
│   │   ├── EncryptionServiceProtocol.swift
│   │   ├── KeychainServiceProtocol.swift
│   │   └── VaultServiceProtocol.swift
│   │
│   ├── Services/
│   │   ├── FileService.swift
│   │   ├── ProgressService.swift        # SwiftData progress + recent files
│   │   ├── FavouriteService.swift       # SwiftData favourites
│   │   ├── ThumbnailService.swift       # Background thumbnail generation
│   │   ├── ArchiveReaderFactory.swift   # Format routing (archives + images + folders)
│   │   ├── ExtractionCache.swift        # Temp file management
│   │   └── Readers/
│   │       ├── ZIPFoundationReader.swift
│   │       ├── PDFReader.swift
│   │       ├── ImageReader.swift        # Single image files
│   │       ├── FolderReader.swift       # Folders of images
│   │       └── LibArchiveReader.swift   # Feature-flagged
│   │
│   ├── ViewModels/
│   │   ├── LibraryViewModel.swift       # Selection mode + favourites
│   │   ├── ReaderViewModel.swift        # Progress + bookmarks
│   │   └── RecentFilesViewModel.swift   # Recent files query
│   │
│   ├── Views/
│   │   ├── Library/
│   │   │   ├── LibraryView.swift        # Selection mode + swipe actions
│   │   │   └── FileRowView.swift        # Thumbnails + favourite indicator
│   │   ├── Reader/
│   │   │   ├── ReaderView.swift
│   │   │   ├── PageView.swift
│   │   │   ├── ReaderControlsView.swift
│   │   │   └── PageSliderView.swift
│   │   └── Components/
│   │       ├── ZoomableImageView.swift  # Pinch-zoom + pan
│   │       ├── ThumbnailView.swift      # Async loading from service
│   │       ├── LoadingView.swift
│   │       └── ErrorView.swift
│   │
│   ├── Utilities/
│   │   ├── Constants.swift              # Includes UserDefaults keys
│   │   ├── FileTypes.swift
│   │   └── ArchiveLimits.swift          # Security constants
│   │
│   └── Resources/
│       ├── Assets.xcassets
│       └── Info.plist
│
├── inkypanelsTests/
│   └── Fixtures/
│
└── docs/
    ├── inkypanels_plan.md
    └── architecture_decisions.md
```

---

## Next Steps

### Completed

- [x] Phase 0: Foundation - Project structure, models, error types
- [x] Phase 0.1: Walking Skeleton - FileService, basic reader flow
- [x] Phase 1B: Archive Support - PDF, streaming architecture, security
- [x] Phase 1C: Reader Experience - Zoom, pan, progress persistence, bookmarks
- [x] Library Features - Thumbnails, favourites, recent files, bulk delete, image/folder readers, settings

### Next: Phase 1D - Secure Vault

1. Create PasswordEntryView UI
2. Implement KeychainService for password storage
3. Add Face ID / Touch ID authentication
4. Create EncryptionService with AES-256-GCM
5. Implement vault manifest encryption
6. Build VaultView file browser
7. Add "Move to Vault" / "Remove from Vault" actions
8. Implement secure temporary file handling
9. Hide .vault folder from normal browsing

### Blocked: libarchive Integration

libarchive infrastructure is ready (`LibArchiveReader` with feature flag). Requires:

1. Build libarchive for iOS (arm64) and simulator
2. Create XCFramework bundle
3. Add to project with bridging header
4. Enable `LIBARCHIVE_ENABLED` compilation condition

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2024-12-25 | Initial architecture decisions |
| 2.0 | 2024-12-26 | Major revision: streaming extraction, security hardening, build-time feature flags |
| 2.1 | 2024-12-26 | Phase 1C complete: SwiftData progress persistence, ZoomableImageView, bookmarks |
| 2.2 | 2025-12-26 | Library Features: ADRs 17-21 (SHA256 IDs, ImageReader, FolderReader, ThumbnailService, Favourites, Recent Files) |
