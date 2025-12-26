# inkypanels - Architecture Decisions Record

This document captures architectural decisions for the inkypanels project.

> **Last Updated**: 2024-12-26
> **Status**: Phase 1C complete - Reader experience implemented

---

## Development Progress

| Phase | Status | Notes |
|-------|--------|-------|
| Phase 0: Foundation | Complete | Project structure, models, protocols |
| Phase 0.1: Walking Skeleton | Complete | FileService, basic reader, navigation |
| Phase 1B: Archive Support | Complete | PDF, streaming extraction, security |
| Phase 1C: Reader Experience | Complete | Zoom, pan, progress persistence, bookmarks |
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
| **v0.2** | ZoomableImageView (pinch/pan), reading controls overlay, progress persistence | Medium | Next |
| **v0.3** | libarchive XCFramework for CBR/CB7, RAR5 detection | High | Blocked on build |
| **v0.4** | Secure vault with AES-256 encryption | High | Planned |

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

### Thumbnail Cache (Planned)
- **Location**: `Caches/Thumbnails/`
- **Naming**: SHA-256 hash of file path
- **Size Limit**: 500MB
- **Eviction**: LRU (least recently used)

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

### Planned Protocols (v0.4+)

```swift

// MARK: - Thumbnail Service

protocol ThumbnailServiceProtocol: Sendable {
    func thumbnail(for file: ComicFile) async throws -> Data
    func generateThumbnail(from imageData: Data, size: CGSize) async throws -> Data
    func clearCache() async
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
│   │   ├── InkyPanelsApp.swift
│   │   ├── ContentView.swift            # Root navigation
│   │   └── AppState.swift
│   │
│   ├── Models/
│   │   ├── ComicFile.swift
│   │   ├── ComicPage.swift              # Legacy (being phased out)
│   │   ├── ArchiveEntry.swift           # NEW: Page metadata
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
│   │   ├── ArchiveReader.swift          # NEW: Streaming extraction
│   │   ├── FileServiceProtocol.swift
│   │   ├── ProgressServiceProtocol.swift
│   │   ├── ThumbnailServiceProtocol.swift
│   │   ├── EncryptionServiceProtocol.swift
│   │   ├── KeychainServiceProtocol.swift
│   │   └── VaultServiceProtocol.swift
│   │
│   ├── Services/
│   │   ├── FileService.swift
│   │   ├── ArchiveReaderFactory.swift   # NEW: Format routing
│   │   ├── ExtractionCache.swift        # NEW: Temp file management
│   │   └── Readers/                     # NEW: Backend implementations
│   │       ├── ZIPFoundationReader.swift
│   │       ├── PDFReader.swift
│   │       └── LibArchiveReader.swift
│   │
│   ├── ViewModels/
│   │   ├── LibraryViewModel.swift
│   │   └── ReaderViewModel.swift
│   │
│   ├── Views/
│   │   ├── Library/
│   │   │   ├── LibraryView.swift
│   │   │   └── FileRowView.swift
│   │   ├── Reader/
│   │   │   ├── ReaderView.swift
│   │   │   ├── PageView.swift
│   │   │   ├── ReaderControlsView.swift
│   │   │   └── PageSliderView.swift
│   │   └── Components/
│   │       ├── ThumbnailView.swift
│   │       ├── LoadingView.swift
│   │       └── ErrorView.swift
│   │
│   ├── Utilities/
│   │   ├── Constants.swift
│   │   ├── FileTypes.swift
│   │   └── ArchiveLimits.swift          # NEW: Security constants
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

### Next: Phase 1D - Secure Vault

1. Create PasswordEntryView UI
2. Implement KeychainService for password storage
3. Add Face ID / Touch ID authentication
4. Create EncryptionService with AES-256-GCM
5. Implement vault manifest encryption
6. Build VaultView file browser
7. Add "Move to Vault" / "Remove from Vault" actions

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
