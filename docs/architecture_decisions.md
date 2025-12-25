# inkypanels - Architecture Decisions Record

This document captures all architectural decisions made before development began.

---

## 1. Dependency Injection Strategy

**Decision**: Environment Objects

**Details**:
- Services defined as protocols with `@Observable` implementations
- Registered at app root via `.environment()` modifier
- ViewModels access services via `@Environment` property wrapper
- Tests inject mock implementations

**Example**:
```swift
protocol ArchiveServiceProtocol {
    func extractPages(from url: URL) async throws -> [ComicPage]
}

@Observable
final class ArchiveService: ArchiveServiceProtocol { ... }

// In App root:
.environment(ArchiveService() as ArchiveServiceProtocol)
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

**Decision**: Actor-Based Services

**Details**:
- All services that perform I/O or heavy computation are Swift actors
- Automatic thread safety without manual synchronization
- ViewModels marked `@MainActor` for UI updates
- Async/await throughout (no completion handlers)

**Example**:
```swift
actor ArchiveService: ArchiveServiceProtocol {
    func extractPages(from url: URL) async throws -> [ComicPage] {
        // Runs on actor's isolated context, off main thread
    }
}

@MainActor
@Observable
final class ReaderViewModel {
    func loadComic(at url: URL) async {
        do {
            let pages = try await archiveService.extractPages(from: url)
            self.pages = pages  // UI update on main thread
        } catch {
            self.error = error
        }
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

| Version | Features | Risk Level |
|---------|----------|------------|
| **v0.1** | File browser, images, CBZ (ZIPFoundation), basic navigation, reading progress | Low |
| **v0.2** | ZoomableImageView (pinch/pan), PDF support, reading controls overlay | Medium |
| **v0.3** | libarchive integration for CBR/CB7, RAR5 detection | High |
| **v0.4** | Secure vault with AES-256 encryption | High |

**Rationale**: De-risk by getting core reading working before tackling C bridging and encryption.

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

### Page Image Cache
- **Strategy**: Windowed cache (current page ± 3 pages)
- **Max Pages in Memory**: 7
- **Prefetch**: Load next 3 pages as user reads
- **Eviction**: Remove pages > 3 positions from current

### Thumbnail Cache
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

| Package | Purpose | Version |
|---------|---------|---------|
| [ZIPFoundation](https://github.com/weichsel/ZIPFoundation) | CBZ/ZIP extraction | Latest stable |
| [swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing) | View regression tests | Latest stable |

### Future (v0.3+)

| Package | Purpose |
|---------|---------|
| libarchive | CBR/CB7 extraction (C library) |

---

## Service Protocol Definitions

These protocols should be defined in Phase 0 before any implementation:

```swift
// MARK: - Archive Service

protocol ArchiveServiceProtocol: Sendable {
    func extractPages(from url: URL) async throws -> [ComicPage]
    func extractPage(at index: Int, from url: URL) async throws -> ComicPage
    func pageCount(for url: URL) async throws -> Int
    func extractCoverImage(from url: URL) async throws -> Data
}

// MARK: - File Service

protocol FileServiceProtocol: Sendable {
    func listFiles(in directory: URL) async throws -> [ComicFile]
    func fileExists(at url: URL) -> Bool
    func moveFile(from source: URL, to destination: URL) async throws
    func deleteFile(at url: URL) async throws
    func importFile(from source: URL, to destination: URL) async throws -> URL
    func detectFileType(at url: URL) async throws -> ComicFileType
}

// MARK: - Progress Service

protocol ProgressServiceProtocol: Sendable {
    func saveProgress(_ progress: ReadingProgress) async throws
    func loadProgress(for comicId: UUID) async throws -> ReadingProgress?
    func markAsCompleted(comicId: UUID) async throws
    func deleteProgress(for comicId: UUID) async throws
}

// MARK: - Image Cache Service

protocol ImageCacheServiceProtocol: Sendable {
    func cacheImage(_ data: Data, for key: String) async
    func retrieveImage(for key: String) async -> Data?
    func prefetchPages(_ indices: [Int], from url: URL) async
    func clearCache() async
}

// MARK: - Thumbnail Service

protocol ThumbnailServiceProtocol: Sendable {
    func thumbnail(for file: ComicFile) async throws -> Data
    func generateThumbnail(from imageData: Data, size: CGSize) async throws -> Data
    func clearCache() async
    func cacheSize() async -> Int64
}

// MARK: - Encryption Service (v0.4)

protocol EncryptionServiceProtocol: Sendable {
    func encrypt(data: Data, withKey key: SymmetricKey) async throws -> Data
    func decrypt(data: Data, withKey key: SymmetricKey) async throws -> Data
    func deriveKey(from password: String, salt: Data) async throws -> SymmetricKey
    func generateSalt() -> Data
}

// MARK: - Keychain Service (v0.4)

protocol KeychainServiceProtocol: Sendable {
    func save(_ data: Data, for key: String, requireBiometric: Bool) async throws
    func retrieve(for key: String, prompt: String) async throws -> Data?
    func delete(for key: String) async throws
    func exists(for key: String) -> Bool
}

// MARK: - Vault Service (v0.4)

protocol VaultServiceProtocol: Sendable {
    func unlock(withPassword password: String) async throws
    func unlockWithBiometric() async throws
    func lock()
    var isUnlocked: Bool { get }
    func addFile(_ file: ComicFile) async throws
    func removeFile(_ file: VaultItem) async throws
    func listFiles() async throws -> [VaultItem]
    func decryptFile(_ item: VaultItem) async throws -> URL
}
```

---

## Directory Structure (Updated)

```
inkypanels/
├── inkypanels.xcodeproj
├── inkypanels/
│   ├── App/
│   │   ├── InkyPanelsApp.swift
│   │   └── AppState.swift              # Shared observable state
│   │
│   ├── Models/
│   │   ├── ComicFile.swift
│   │   ├── ComicPage.swift
│   │   ├── ReadingProgress.swift
│   │   ├── VaultItem.swift
│   │   └── Errors/
│   │       ├── InkyPanelsError.swift
│   │       ├── ArchiveError.swift
│   │       ├── VaultError.swift
│   │       ├── FileSystemError.swift
│   │       └── ReaderError.swift
│   │
│   ├── Protocols/                       # All service protocols
│   │   ├── ArchiveServiceProtocol.swift
│   │   ├── FileServiceProtocol.swift
│   │   ├── ProgressServiceProtocol.swift
│   │   ├── ImageCacheServiceProtocol.swift
│   │   ├── ThumbnailServiceProtocol.swift
│   │   ├── EncryptionServiceProtocol.swift
│   │   ├── KeychainServiceProtocol.swift
│   │   └── VaultServiceProtocol.swift
│   │
│   ├── Services/                        # Protocol implementations
│   │   ├── ArchiveService.swift
│   │   ├── FileService.swift
│   │   ├── ProgressService.swift
│   │   ├── ImageCacheService.swift
│   │   ├── ThumbnailService.swift
│   │   └── (vault services in v0.4)
│   │
│   ├── ViewModels/
│   │   ├── LibraryViewModel.swift
│   │   ├── ReaderViewModel.swift
│   │   └── VaultViewModel.swift
│   │
│   ├── Views/
│   │   └── (as in original plan)
│   │
│   └── Utilities/
│       └── (as in original plan)
│
├── inkypanelsTests/
│   ├── Mocks/                           # Mock service implementations
│   │   ├── MockArchiveService.swift
│   │   ├── MockFileService.swift
│   │   └── ...
│   │
│   ├── Services/
│   │   ├── ArchiveServiceTests.swift
│   │   ├── FileServiceTests.swift
│   │   └── ...
│   │
│   ├── ViewModels/
│   │   ├── LibraryViewModelTests.swift
│   │   └── ReaderViewModelTests.swift
│   │
│   ├── Snapshots/
│   │   └── __Snapshots__/               # Reference images
│   │
│   └── Fixtures/
│       ├── sample.cbz
│       ├── sample-images/
│       └── corrupted.cbz
│
└── docs/
    ├── inkypanels_plan.md
    └── architecture_decisions.md         # This document
```

---

## Next Steps

### Phase 0: Foundation (Before Features)

1. Create Xcode project with folder structure above
2. Add Swift packages (ZIPFoundation, swift-snapshot-testing)
3. Define all error types
4. Define all service protocols (even those implemented later)
5. Create AppState skeleton
6. Set up test target with fixture files
7. Configure CI (optional but recommended)

### Phase 0.1: Walking Skeleton

1. Implement FileService (list files, detect types)
2. Implement basic ArchiveService (CBZ extraction only)
3. Create minimal LibraryView (file list)
4. Create minimal ReaderView (display pages, swipe navigation)
5. Verify full flow: Browse → Open CBZ → View Pages → Navigate

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2024-12-25 | Initial architecture decisions |
