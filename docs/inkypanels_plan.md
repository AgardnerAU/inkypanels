# inkypanels - Comic Book Reader for iPad

## Project Overview

**inkypanels** is a comic book reader application for iPad, built with SwiftUI. It provides a seamless reading experience for digital comics with support for multiple file formats, secure vault storage for private content, and intuitive touch-based navigation.

### Target Platform
- **Primary**: iPad (iPadOS 17.0+)
- **Secondary**: iPhone (future consideration)
- **Development**: macOS with Xcode

### Distribution Strategy
- **Phase 1**: Personal use via Xcode sideloading (free)
- **Phase 2**: App Store distribution (requires $99/year Apple Developer Program)

---

## Technology Stack

| Component | Choice | Rationale |
|-----------|--------|-----------|
| Language | Swift 5.9+ | Native iOS development, modern syntax |
| UI Framework | SwiftUI | Declarative, great for iPad, live previews |
| Minimum iOS | 17.0 | Latest SwiftUI features, NavigationStack |
| Architecture | MVVM | Clean separation, testable, SwiftUI-friendly |
| Data Persistence | SwiftData | Modern replacement for Core Data |
| Security | CryptoKit + Keychain | Native Apple frameworks, proven security |

---

## Feature Roadmap

### Phase 1: MVP (Minimum Viable Product)

> **Status**: Phase 1 MVP complete. Device testing pending. Phase 2 (Enhanced Experience) next.

#### Core Reading Experience
- [x] Open and display image files (PNG, JPG, WEBP, TIFF)
- [x] Open CBZ/ZIP comic archives
- [ ] Open CBR/RAR comic archives (RAR4 format) - *infrastructure ready, needs libarchive*
- [ ] Open CB7/7z comic archives - *infrastructure ready, needs libarchive*
- [x] Open PDF files with page extraction
- [x] Full-screen reading mode
- [x] Swipe navigation between pages
- [x] Tap zones for navigation (left/right/center)
- [x] Pinch-to-zoom with pan
- [x] Auto-fit modes (fit width, fit height, fit screen)
- [x] Support both portrait and landscape orientations

#### File Management
- [x] Browse Documents folder
- [x] Navigate folder hierarchy
- [x] Display file thumbnails (background generation with disk cache)
- [x] Sort files (name, date, size)
- [x] Recent files list (with progress bars and swipe-to-remove)
- [x] Import via Files app / iTunes file sharing
- [x] Bulk delete with selection mode
- [x] Favourite files (swipe-to-favourite with star indicators)
- [x] Open single image files (JPG, PNG, etc.)
- [x] Open folders of images as multi-page comics

#### Reading Progress
- [x] Remember last page per comic
- [x] Bookmark support
- [x] Resume reading from last position
- [x] Track read/unread status (via isCompleted in ProgressRecord)

#### Secure Vault
- [x] Password-protected vault folder
- [x] Face ID / Touch ID authentication option
- [x] AES-256 encryption for vault contents
- [x] Hidden vault (invisible until authenticated)
- [x] Move files to/from vault
- [x] Files inaccessible via PC/Mac connection when encrypted

---

### Phase 2: Enhanced Experience

#### Library Management
- [ ] Comic metadata display (from ComicInfo.xml)
- [ ] Cover thumbnail grid view
- [ ] Search functionality
- [ ] Rating system (1-5 stars)
- [ ] Collections / custom folders
- [ ] Filter by read status

#### Reading Enhancements
- [ ] Double-page spread view
- [ ] Reading direction toggle (LTR/RTL for manga)
- [ ] Brightness control
- [ ] Background color options

#### Statistics
- [ ] Reading time tracking
- [ ] Comics read count
- [ ] Pages read count
- [ ] Reading streaks

---

### Phase 3: Advanced Features

#### Additional Features
- [ ] Boss key (quick hide to decoy screen)
- [ ] Image transition animations
- [ ] Auto-slideshow mode with configurable timing
- [ ] Magnifier tool
- [x] Bulk file operations (moved to Phase 1)

#### Cloud & Sync
- [ ] iCloud sync for reading progress
- [ ] iCloud sync for library metadata
- [ ] Dropbox integration
- [ ] Google Drive integration

#### Additional Formats
- [ ] CBA (ACE archives) - if library support available
- [ ] WebP image support
- [ ] HEIC image support

---

## Project Structure

> **Updated**: 2025-12-26 - Reflects Phase 1D (Secure Vault) completion

```
inkypanels/
├── inkypanels.xcodeproj
├── project.yml                          # XcodeGen configuration
├── Package.swift                        # SPM for testing
├── inkypanels/
│   ├── App/
│   │   ├── InkyPanelsApp.swift          # App entry point + SwiftData container
│   │   ├── ContentView.swift            # Root navigation + RecentFilesView + SettingsView
│   │   └── AppState.swift               # Shared observable state
│   │
│   ├── Models/
│   │   ├── ComicFile.swift              # Comic file representation + ComicFileType
│   │   ├── ArchiveEntry.swift           # Page metadata (SHA256 ID)
│   │   ├── ProgressRecord.swift         # SwiftData model for progress
│   │   ├── FavouriteRecord.swift        # SwiftData model for favourites (NEW)
│   │   ├── ReadingProgress.swift        # Progress tracking struct
│   │   └── Errors/
│   │       ├── InkyPanelsError.swift    # Top-level error enum
│   │       ├── ArchiveError.swift
│   │       ├── FileSystemError.swift
│   │       ├── ReaderError.swift
│   │       └── VaultError.swift
│   │
│   ├── Protocols/
│   │   ├── ArchiveReader.swift          # Streaming extraction protocol
│   │   ├── ProgressServiceProtocol.swift # Progress persistence
│   │   ├── ThumbnailServiceProtocol.swift # Thumbnail generation
│   │   ├── FileServiceProtocol.swift
│   │   └── (vault protocols for v0.4)
│   │
│   ├── Services/
│   │   ├── FileService.swift            # File system operations
│   │   ├── ProgressService.swift        # SwiftData progress persistence
│   │   ├── FavouriteService.swift       # SwiftData favourites
│   │   ├── ThumbnailService.swift       # Background thumbnail generation
│   │   ├── ArchiveReaderFactory.swift   # Format routing (images + folders)
│   │   ├── ExtractionCache.swift        # Temp file management
│   │   ├── EncryptionService.swift      # AES-256-GCM encryption (NEW)
│   │   ├── KeychainService.swift        # Secure keychain storage (NEW)
│   │   ├── VaultService.swift           # Vault orchestration (NEW)
│   │   └── Readers/                     # Archive backends
│   │       ├── ZIPFoundationReader.swift
│   │       ├── PDFReader.swift
│   │       ├── ImageReader.swift        # Single image files
│   │       ├── FolderReader.swift       # Folders of images
│   │       └── LibArchiveReader.swift   # Feature-flagged
│   │
│   ├── ViewModels/
│   │   ├── LibraryViewModel.swift       # Selection + favourites + vault
│   │   ├── ReaderViewModel.swift        # Progress + bookmark logic
│   │   ├── RecentFilesViewModel.swift   # Recent files query
│   │   └── VaultViewModel.swift         # Vault state management (NEW)
│   │
│   ├── Views/
│   │   ├── Library/
│   │   │   ├── LibraryView.swift        # Selection mode + swipe actions + vault
│   │   │   └── FileRowView.swift        # Thumbnails + favourite indicator
│   │   ├── Reader/
│   │   │   ├── ReaderView.swift
│   │   │   ├── PageView.swift           # Wraps ZoomableImageView
│   │   │   ├── ReaderControlsView.swift # Fit mode + bookmark toggle
│   │   │   └── PageSliderView.swift
│   │   ├── Vault/                       # Secure vault views (NEW)
│   │   │   ├── VaultView.swift          # Main router view
│   │   │   ├── VaultSetupView.swift     # Initial vault creation
│   │   │   ├── VaultUnlockView.swift    # Password/biometric unlock
│   │   │   ├── VaultFileListView.swift  # File list + VaultReaderView
│   │   │   └── VaultSettingsView.swift  # Toggle biometrics, change password
│   │   └── Components/
│   │       ├── ZoomableImageView.swift  # Pinch-zoom + pan
│   │       ├── ThumbnailView.swift      # Async loading from ThumbnailService
│   │       ├── LoadingView.swift
│   │       └── ErrorView.swift
│   │
│   ├── Utilities/
│   │   ├── Constants.swift              # Includes new UserDefaults keys
│   │   ├── FileTypes.swift              # Magic bytes detection
│   │   └── ArchiveLimits.swift          # Security constants
│   │
│   ├── Resources/
│   │   ├── Assets.xcassets
│   │   └── Info.plist
│   │
│   └── Preview Content/
│
├── inkypanelsTests/
│   └── Fixtures/                        # Test CBZ/PDF files
│
└── docs/
    ├── inkypanels_plan.md               # This document
    └── architecture_decisions.md        # ADRs
```

---

## Dependencies

### Current (v0.1)

| Library | Version | License | Purpose | Status |
|---------|---------|---------|---------|--------|
| ZIPFoundation | 0.9+ | MIT | CBZ/ZIP extraction | **Active** |
| swift-snapshot-testing | 1.15+ | MIT | View regression tests | Active |

### Native Frameworks

| Framework | Purpose | Status |
|-----------|---------|--------|
| SwiftUI | User interface | Active |
| PDFKit | PDF page extraction | **Active** |
| CryptoKit | AES-256 encryption | **Active** |
| LocalAuthentication | Face ID / Touch ID | **Active** |

### Future (v0.3) - libarchive

| Library | Version | License | Purpose | Status |
|---------|---------|---------|---------|--------|
| libarchive | 3.7+ | BSD | RAR/7z extraction | Infrastructure ready |

**Current Format Support**:

| Format | Extension | Status | Backend |
|--------|-----------|--------|---------|
| ZIP | .zip, .cbz | **Working** | ZIPFoundationReader |
| PDF | .pdf | **Working** | PDFReader (PDFKit) |
| Single Images | .jpg, .png, .gif, .webp, .tiff, .heic | **Working** | ImageReader |
| Image Folders | (directories) | **Working** | FolderReader |
| RAR 4.x | .rar, .cbr | Placeholder | LibArchiveReader (needs build) |
| RAR 5.x | .rar, .cbr | Detected, error shown | N/A |
| 7-Zip | .7z, .cb7 | Placeholder | LibArchiveReader (needs build) |

### RAR5 Detection (Implemented)

```swift
// FileTypes.swift
static func isRAR5(data: Data) -> Bool {
    let bytes = [UInt8](data.prefix(8))
    return bytes == [0x52, 0x61, 0x72, 0x21, 0x1A, 0x07, 0x01, 0x00]
}
```

User sees: *"This comic uses RAR5 format which isn't currently supported. Please convert to CBZ format for best compatibility."*

---

## Architecture Details

### MVVM Pattern

```
┌─────────────────────────────────────────────────────────┐
│                        View                              │
│   (SwiftUI Views - LibraryView, ReaderView, etc.)       │
│                          │                               │
│                          ▼                               │
│                    ViewModel                             │
│   (ObservableObject - LibraryViewModel, etc.)           │
│         │                              │                 │
│         ▼                              ▼                 │
│      Model                         Services              │
│   (Data structures)        (FileService, ArchiveService) │
└─────────────────────────────────────────────────────────┘
```

### Data Flow

```
User Action → View → ViewModel → Service → File System
                ↑                              │
                └──────── State Update ────────┘
```

---

## Data Models

### ComicFile

```swift
struct ComicFile: Identifiable, Hashable {
    let id: UUID
    let url: URL
    let name: String
    let fileType: ComicFileType
    let fileSize: Int64
    let modifiedDate: Date
    let pageCount: Int?
    var readingProgress: ReadingProgress?
    var rating: Int?
    var isInVault: Bool
}

enum ComicFileType: String, CaseIterable {
    case cbz, cbr, cb7, pdf, zip, rar, sevenZip
    case image  // Folder of images
    case png, jpg, webp, tiff  // Single images
}
```

### ReadingProgress

```swift
struct ReadingProgress: Codable {
    let comicId: UUID
    var currentPage: Int
    var totalPages: Int
    var lastReadDate: Date
    var isCompleted: Bool
    var bookmarks: [Int]  // Bookmarked page numbers

    var percentComplete: Double {
        guard totalPages > 0 else { return 0 }
        return Double(currentPage) / Double(totalPages) * 100
    }
}
```

### VaultItem

```swift
struct VaultItem: Identifiable, Codable {
    let id: UUID
    let originalName: String
    let encryptedFileName: String  // Random UUID filename
    let addedDate: Date
    let fileSize: Int64
    let fileType: ComicFileType
}
```

---

## Data Persistence

### Storage Locations

| Data Type | Storage Method | Location |
|-----------|---------------|----------|
| Reading Progress | SwiftData | App container |
| Recent Files | SwiftData | App container |
| User Settings | UserDefaults | App container |
| Vault Password | Keychain | Secure enclave |
| Vault Manifest | Encrypted JSON | Documents/.vault/ |
| Comic Files | File System | Documents/ |
| Encrypted Files | File System | Documents/.vault/files/ |
| Thumbnail Cache | File System | Caches/ |

### UserDefaults Keys

```swift
enum UserDefaultsKey: String {
    case lastOpenedFile
    case defaultFitMode          // fitWidth, fitHeight, fitScreen
    case readingDirection        // leftToRight, rightToLeft
    case showPageNumbers
    case autoHideControls
    case recentFilesLimit
    case thumbnailSize
}
```

### Keychain Storage

```swift
// Vault password stored securely
KeychainService.save(password: hashedPassword,
                     forKey: "inkypanels.vault.password",
                     withBiometrics: true)
```

---

## Security Implementation

### Vault Architecture

```
Documents/
├── Comics/                    # Regular, accessible files
│   ├── Batman Vol 1.cbz
│   └── Spider-Man/
│       └── Issue 001.cbr
│
└── .vault/                    # Hidden folder (dot prefix)
    ├── manifest.encrypted     # Encrypted file index
    └── files/
        ├── a1b2c3d4.enc      # Encrypted comic (random name)
        ├── e5f6g7h8.enc      # Encrypted comic (random name)
        └── ...
```

### Encryption Flow

```
Adding File to Vault:
1. User selects file and confirms
2. Generate random filename (UUID)
3. Read original file data
4. Generate random IV (initialization vector)
5. Encrypt with AES-256-GCM using vault key
6. Write: IV + encrypted data to .vault/files/[uuid].enc
7. Update encrypted manifest with mapping
8. Securely delete original file

Opening File from Vault:
1. User authenticates (password or Face ID)
2. Derive key from password using PBKDF2
3. Decrypt manifest to get file mappings
4. User selects file to read
5. Decrypt file to temporary location
6. Open in reader
7. Delete temporary file when closed
```

### Encryption Details

```swift
// Key derivation
let salt = savedSalt ?? generateRandomSalt(32)
let key = PBKDF2<SHA256>.deriveKey(
    fromPassword: password,
    salt: salt,
    iterations: 100_000,
    derivedKeyLength: 32
)

// Encryption (AES-256-GCM)
let sealedBox = try AES.GCM.seal(plaintext, using: key)
let encryptedData = sealedBox.combined  // nonce + ciphertext + tag

// Decryption
let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
let plaintext = try AES.GCM.open(sealedBox, using: key)
```

---

## Implementation Tasks

### Phase 1A: Foundation ✅ Complete

| # | Task | Status | Notes |
|---|------|--------|-------|
| 1 | Create Xcode project with SwiftUI template | ✅ | Using XcodeGen |
| 2 | Configure project settings | ✅ | iPad-only, iOS 17+ |
| 3 | Set up folder structure | ✅ | See Project Structure |
| 4 | Implement NavigationSplitView layout | ✅ | Sidebar + detail |
| 5 | Create FileService | ✅ | Actor-based |
| 6 | Build LibraryView with file listing | ✅ | With sorting |
| 7 | Display image files | ✅ | PNG, JPG, etc. |
| 8 | Create basic ReaderView | ✅ | Full-screen |
| 9 | Implement swipe navigation | ✅ | DragGesture |
| 10 | Add tap zones | ✅ | Left/Center/Right |

### Phase 1B: Archive Support ✅ Complete (partial)

| # | Task | Status | Notes |
|---|------|--------|-------|
| 11 | libarchive XCFramework | ⏸️ | Infrastructure ready, build pending |
| 12 | LibArchiveReader wrapper | ✅ | Feature-flagged placeholder |
| 13 | ArchiveReader protocol | ✅ | **Redesigned**: streaming extraction |
| 14 | ZIP/CBZ extraction | ✅ | ZIPFoundationReader |
| 15 | RAR4/CBR extraction | ⏸️ | Needs libarchive build |
| 16 | RAR5 detection | ✅ | User-friendly error |
| 17 | 7z/CB7 extraction | ⏸️ | Needs libarchive build |
| 18 | PDFReader using PDFKit | ✅ | Page rendering |
| 19 | Page caching system | ✅ | **Redesigned**: ExtractionCache with temp files |
| 20 | Extraction progress indicator | ✅ | Loading status + progress bar |

**Architecture Note**: Phase 1B was redesigned to use streaming extraction (temp files) instead of in-memory Data arrays. See ADR #14 in architecture_decisions.md.

### Phase 1C: Reader Experience ✅ Complete

| # | Task | Status | Notes |
|---|------|--------|-------|
| 21 | Implement ZoomableImageView with pinch-zoom | ✅ | 1x-5x zoom with MagnifyGesture |
| 22 | Add pan gesture while zoomed | ✅ | DragGesture when scale > 1.0 |
| 23 | Create auto-fit modes (width, height, screen) | ✅ | FitMode enum with menu selector |
| 24 | Build ReaderControlsView overlay | ✅ | Top bar + bottom slider |
| 25 | Add page slider/scrubber | ✅ | PageSliderView already existed |
| 26 | Implement full-screen mode | ✅ | Already implemented in Phase 1A |
| 27 | Create ProgressService for persistence | ✅ | SwiftData with ProgressRecord model |
| 28 | Save reading progress on page change | ✅ | Saves on every navigation |
| 29 | Restore last position on open | ✅ | Loads from ProgressRecord |
| 30 | Add bookmark functionality | ✅ | Toggle button + persistence |

**Implementation Notes**:
- `ZoomableImageView` supports double-tap to toggle between 1x and 2.5x zoom
- Progress uses file path as stable identifier (persists across app launches)
- Bookmarks stored as page indices in `ProgressRecord.bookmarks` array

### Library Features ✅ Complete

| # | Task | Status | Notes |
|---|------|--------|-------|
| - | Fix ArchiveEntry.id to use SHA256 hash | ✅ | Prevents 255-byte filename limit errors |
| - | Add ImageReader for single images | ✅ | JPG, PNG, GIF, WEBP, TIFF, HEIC support |
| - | Add FolderReader for image folders | ✅ | Natural sorting, multi-page reading |
| - | Implement ThumbnailService | ✅ | Background generation, disk cache |
| - | Integrate thumbnails in FileRowView | ✅ | Async loading with placeholder |
| - | Implement bulk delete with selection | ✅ | Select All, confirmation dialog |
| - | Create FavouriteRecord SwiftData model | ✅ | Unique filePath constraint |
| - | Create FavouriteService | ✅ | Toggle, batch status queries |
| - | Add swipe-to-favourite in LibraryView | ✅ | Star indicator on favourites |
| - | Implement RecentFilesView | ✅ | Progress bars, relative timestamps |
| - | Create RecentFilesViewModel | ✅ | Filters missing files |
| - | Implement SettingsView | ✅ | Recent tab visibility, vault filtering |
| - | Add conditional Recent tab display | ✅ | Respects showRecentFiles setting |

**Implementation Notes**:
- SHA256 hashes used for ArchiveEntry IDs and cache directory names (64 chars, always filesystem-safe)
- ThumbnailService caches to `Caches/Thumbnails/` with SHA256-based filenames
- Favourites use SwiftData with unique filePath constraint
- Recent files query ProgressRecord sorted by lastReadDate, filters vault files if setting enabled

### Phase 1D: Secure Vault ✅ Complete

| # | Task | Status | Notes |
|---|------|--------|-------|
| 31 | Create PasswordEntryView UI | ✅ | VaultSetupView + VaultUnlockView |
| 32 | Implement KeychainService | ✅ | Actor-based with biometric support |
| 33 | Add Face ID / Touch ID authentication | ✅ | Optional, user chooses during setup |
| 34 | Create EncryptionService with AES-256-GCM | ✅ | PBKDF2 600k iterations |
| 35 | Implement vault manifest encryption | ✅ | Encrypted JSON manifest |
| 36 | Build VaultView file browser | ✅ | VaultFileListView with VaultReaderView |
| 37 | Add "Move to Vault" action | ✅ | Swipe action in LibraryView |
| 38 | Add "Remove from Vault" action | ✅ | Swipe action in VaultFileListView |
| 39 | Implement secure temporary file handling | ✅ | Cleaned up on lock/background |
| 40 | Hide .vault folder from normal browsing | ✅ | Hidden folder + dot prefix |

**Implementation Notes**:
- All vault services are actors for thread safety
- Biometric is optional - user can always use password only
- VaultSettingsView allows toggling biometrics, changing password, deleting vault
- Files securely deleted (overwritten with random data before deletion)

### Phase 1E: Polish & Testing ✅ Complete

| # | Task | Priority | Status |
|---|------|----------|--------|
| 41 | Add app icon and launch screen | Medium | ✅ Done |
| 42 | Implement recent files list | Medium | ✅ Done (Library Features) |
| 43 | Add pull-to-refresh in library | Low | ✅ Done (already implemented) |
| 44 | Create error handling and user feedback | High | ✅ Done (ErrorView with all error types) |
| 45 | Optimize memory usage for large files | High | ✅ Done (streaming extraction) |
| 46 | Test on physical iPad device | High | Pending (requires device) |
| 47 | Fix orientation handling issues | Medium | ✅ Done (zoom resets on rotation) |
| 48 | Performance testing with large libraries | Medium | Pending (requires device) |

**Implementation Notes**:
- App icon uses 1024x1024 comic panel design
- Launch screen centers logo on white background
- ErrorView handles InkyPanelsError, ArchiveError, VaultError, ReaderError, FileSystemError with appropriate SF Symbols
- ZoomableImageView resets zoom on orientation change to prevent offset issues

---

## File Type Handling

### Supported Extensions

```swift
enum SupportedFormat {
    static let images: Set<String> = ["png", "jpg", "jpeg", "webp", "tiff", "tif", "gif", "heic"]
    static let comics: Set<String> = ["cbz", "cbr", "cb7", "cba"]
    static let archives: Set<String> = ["zip", "rar", "7z"]
    static let documents: Set<String> = ["pdf"]

    static var all: Set<String> {
        images.union(comics).union(archives).union(documents)
    }
}
```

### Magic Bytes Detection

```swift
enum FileMagic {
    static let zip: [UInt8] = [0x50, 0x4B, 0x03, 0x04]
    static let rar4: [UInt8] = [0x52, 0x61, 0x72, 0x21, 0x1A, 0x07, 0x00]
    static let rar5: [UInt8] = [0x52, 0x61, 0x72, 0x21, 0x1A, 0x07, 0x01, 0x00]
    static let sevenZip: [UInt8] = [0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C]
    static let pdf: [UInt8] = [0x25, 0x50, 0x44, 0x46]  // %PDF
    static let png: [UInt8] = [0x89, 0x50, 0x4E, 0x47]
    static let jpg: [UInt8] = [0xFF, 0xD8, 0xFF]
}
```

---

## UI/UX Guidelines

### Navigation Structure

```
┌─────────────────────────────────────────────────┐
│  inkypanels                                      │
├─────────────────────────────────────────────────┤
│                                                  │
│  Sidebar (iPad)        │    Content Area        │
│  ─────────────         │    ────────────        │
│  📁 Library            │                        │
│  🕐 Recent             │    [File Grid or       │
│  🔒 Vault              │     Reader View]       │
│  ⚙️ Settings           │                        │
│                        │                        │
└─────────────────────────────────────────────────┘
```

### Reader Tap Zones

```
┌─────────────────────────────────────┐
│                                     │
│   ◀️ Prev    │  Toggle   │  Next ▶️  │
│    (25%)    │  Controls │  (25%)   │
│             │   (50%)   │          │
│             │           │          │
│             │           │          │
│             │           │          │
└─────────────────────────────────────┘
```

### Gestures

| Gesture | Action |
|---------|--------|
| Tap left edge | Previous page |
| Tap right edge | Next page |
| Tap center | Toggle controls |
| Swipe left | Next page |
| Swipe right | Previous page |
| Pinch | Zoom in/out |
| Double tap | Fit to screen / 100% zoom toggle |
| Long press | Bookmark page |

---

## Testing Strategy

### Unit Tests

- ArchiveService extraction for each format
- EncryptionService encrypt/decrypt roundtrip
- ProgressService save/load
- File type detection
- Magic bytes parsing

### UI Tests

- Navigation flow
- Reader gestures
- Vault authentication
- File import

### Manual Testing Checklist

- [x] Open CBZ file with 100+ pages
- [ ] Open CBR (RAR4) file (blocked on libarchive)
- [x] Attempt to open RAR5 file (should show error)
- [x] Open PDF with images
- [x] Open folder of images
- [x] Open single image file (JPG, PNG, etc.)
- [x] Zoom and pan on detailed page
- [x] Resume reading after app restart
- [x] Swipe to favourite a file
- [x] Bulk select and delete files
- [x] View recent files with progress
- [x] Toggle Recent tab visibility in settings
- [ ] Add file to vault
- [ ] Access vault with Face ID
- [ ] Access vault with password
- [ ] Verify encrypted files via Finder
- [ ] Rotate device while reading
- [ ] Test with low memory warning

---

## Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| libarchive integration complexity | Medium | High | Start with simple ZIP, add RAR later |
| RAR5 user complaints | Low | Medium | Clear error message with conversion suggestion |
| Memory issues with large files | Medium | High | Stream pages, limit cache size |
| Sideloading expiry (7 days) | Certain | Low | Re-sign weekly or get developer account |
| Encryption performance | Low | Medium | Use hardware-accelerated CryptoKit |
| App Review rejection (if publishing) | Medium | High | Follow guidelines, no private APIs |

---

## Future Considerations

### App Store Preparation

If publishing to App Store:

1. **Apple Developer Account**: $99/year enrollment
2. **Privacy Policy**: Required, host on GitHub Pages (free)
3. **App Store Screenshots**: iPad Pro 12.9" and 11" required
4. **App Review**: Allow 24-48 hours, possibly longer
5. **Privacy Nutrition Labels**: Declare data usage
6. **Export Compliance**: AES encryption requires declaration

### Monetization Options

| Model | Pros | Cons |
|-------|------|------|
| Free | Maximum users | No revenue |
| Paid ($2.99-4.99) | One-time revenue | Lower adoption |
| Freemium | Wide adoption + revenue | Development complexity |
| Tip Jar | User goodwill | Minimal revenue |

### Potential Enhancements

- Apple Pencil support for annotations
- Widget for recent comics
- Shortcuts app integration
- SharePlay for reading together
- OPDS catalog support
- ComicVine API integration

---

## Resources

### Documentation

- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)
- [PDFKit Documentation](https://developer.apple.com/documentation/pdfkit)
- [CryptoKit Documentation](https://developer.apple.com/documentation/cryptokit)
- [libarchive Documentation](https://www.libarchive.org/)

### Similar Projects (Reference)

- Panels (App Store) - UI/UX reference
- YACReader - Open source comic reader
- Kavita - Self-hosted comic server

### Design Resources

- SF Symbols - Apple's icon library
- Human Interface Guidelines - iPad design patterns

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 0.1 | 2024-12-25 | Initial planning document |
| 0.2 | 2024-12-26 | Updated for streaming architecture; marked Phase 1A-1B complete |
| 0.3 | 2024-12-26 | Phase 1C complete: zoom, pan, fit modes, progress persistence, bookmarks |
| 0.4 | 2025-12-26 | Library Features complete: thumbnails, favourites, recent files, bulk delete, image/folder readers, settings |
| 0.5 | 2025-12-26 | Phase 1D complete: Secure Vault with AES-256 encryption, Face ID/Touch ID, keychain storage |
| 0.6 | 2025-12-26 | Phase 1E complete: App icon, launch screen, improved error handling, orientation fixes |

---

## Notes

- Development environment: macOS with Xcode 15+ (using XcodeGen)
- Primary testing device: iPad Simulator (iPad Pro 13-inch M5)
- GitHub: https://github.com/AgardnerAU/inkypanels
- This document updated as development progresses
