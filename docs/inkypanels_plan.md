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

#### Core Reading Experience
- [ ] Open and display image files (PNG, JPG, WEBP, TIFF)
- [ ] Open CBZ/ZIP comic archives
- [ ] Open CBR/RAR comic archives (RAR4 format)
- [ ] Open CB7/7z comic archives
- [ ] Open PDF files with page extraction
- [ ] Full-screen reading mode
- [ ] Swipe navigation between pages
- [ ] Tap zones for navigation (left/right/center)
- [ ] Pinch-to-zoom with pan
- [ ] Auto-fit modes (fit width, fit height, fit screen)
- [ ] Support both portrait and landscape orientations

#### File Management
- [ ] Browse Documents folder
- [ ] Navigate folder hierarchy
- [ ] Display file thumbnails
- [ ] Sort files (name, date, size)
- [ ] Recent files list
- [ ] Import via Files app / iTunes file sharing

#### Reading Progress
- [ ] Remember last page per comic
- [ ] Bookmark support
- [ ] Resume reading from last position
- [ ] Track read/unread status

#### Secure Vault
- [ ] Password-protected vault folder
- [ ] Face ID / Touch ID authentication option
- [ ] AES-256 encryption for vault contents
- [ ] Hidden vault (invisible until authenticated)
- [ ] Move files to/from vault
- [ ] Files inaccessible via PC/Mac connection when encrypted

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
- [ ] Bulk file operations

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

```
inkypanels/
├── inkypanels.xcodeproj
├── inkypanels/
│   ├── App/
│   │   ├── inkypanelsApp.swift          # App entry point
│   │   └── ContentView.swift            # Root navigation
│   │
│   ├── Models/
│   │   ├── ComicFile.swift              # Comic file representation
│   │   ├── ComicPage.swift              # Individual page data
│   │   ├── ReadingProgress.swift        # Progress tracking model
│   │   ├── VaultItem.swift              # Encrypted file reference
│   │   └── AppSettings.swift            # User preferences
│   │
│   ├── Views/
│   │   ├── Library/
│   │   │   ├── LibraryView.swift        # Main library browser
│   │   │   ├── FileRowView.swift        # List row component
│   │   │   ├── FolderGridView.swift     # Grid layout option
│   │   │   └── FileDetailView.swift     # File info sheet
│   │   │
│   │   ├── Reader/
│   │   │   ├── ReaderView.swift         # Main reader container
│   │   │   ├── PageView.swift           # Single page display
│   │   │   ├── ZoomableImageView.swift  # Pinch-zoom handling
│   │   │   ├── ReaderControlsView.swift # Navigation overlay
│   │   │   └── PageSliderView.swift     # Page scrubber
│   │   │
│   │   ├── Vault/
│   │   │   ├── VaultView.swift          # Vault file browser
│   │   │   ├── PasswordEntryView.swift  # Password input
│   │   │   └── VaultSettingsView.swift  # Vault configuration
│   │   │
│   │   └── Components/
│   │       ├── ThumbnailView.swift      # Cached thumbnail
│   │       ├── LoadingView.swift        # Loading indicator
│   │       └── ErrorView.swift          # Error display
│   │
│   ├── ViewModels/
│   │   ├── LibraryViewModel.swift       # Library business logic
│   │   ├── ReaderViewModel.swift        # Reader state management
│   │   └── VaultViewModel.swift         # Vault operations
│   │
│   ├── Services/
│   │   ├── FileService.swift            # File system operations
│   │   ├── ArchiveService.swift         # Unified archive interface
│   │   ├── LibArchiveWrapper.swift      # libarchive Swift bridge
│   │   ├── PDFService.swift             # PDF extraction
│   │   ├── ImageService.swift           # Image loading/caching
│   │   ├── EncryptionService.swift      # AES encryption
│   │   ├── KeychainService.swift        # Secure credential storage
│   │   ├── ProgressService.swift        # Reading progress persistence
│   │   └── ThumbnailService.swift       # Thumbnail generation/cache
│   │
│   ├── Libraries/
│   │   └── libarchive/
│   │       ├── include/                 # C headers
│   │       ├── lib/                     # Compiled library
│   │       └── libarchive-Bridging.h    # Swift bridging header
│   │
│   ├── Utilities/
│   │   ├── Extensions/
│   │   │   ├── URL+Extensions.swift
│   │   │   ├── Data+Extensions.swift
│   │   │   ├── Image+Extensions.swift
│   │   │   └── View+Extensions.swift
│   │   ├── Constants.swift              # App-wide constants
│   │   └── FileTypes.swift              # Supported format definitions
│   │
│   ├── Resources/
│   │   ├── Assets.xcassets              # App icons, colors
│   │   ├── Localizable.strings          # Localization
│   │   └── Info.plist                   # App configuration
│   │
│   └── Preview Content/
│       └── Preview Assets.xcassets
│
└── inkypanelsTests/
    ├── ArchiveServiceTests.swift
    ├── EncryptionServiceTests.swift
    └── ProgressServiceTests.swift
```

---

## Dependencies

### Third-Party Libraries

| Library | Version | License | Purpose | App Store Safe |
|---------|---------|---------|---------|----------------|
| libarchive | 3.7+ | BSD | RAR, ZIP, 7z extraction | Yes |
| ZIPFoundation | 0.9+ | MIT | ZIP handling (backup) | Yes |

### Native Frameworks (No External Dependencies)

| Framework | Purpose |
|-----------|---------|
| SwiftUI | User interface |
| PDFKit | PDF rendering and page extraction |
| CryptoKit | AES-256 encryption |
| LocalAuthentication | Face ID / Touch ID |
| QuickLook | File previews (optional) |
| UniformTypeIdentifiers | File type handling |

### libarchive Format Support

| Format | Extension | Read Support | Notes |
|--------|-----------|--------------|-------|
| ZIP | .zip, .cbz | Full | Standard comic format |
| RAR 4.x | .rar, .cbr | Full | Legacy RAR format |
| RAR 5.x | .rar, .cbr | None | Show user-friendly error |
| 7-Zip | .7z, .cb7 | Full | LZMA compression |
| TAR | .tar | Full | Uncompressed archives |
| GZip | .tar.gz | Full | Compressed TAR |

### RAR5 Limitation

libarchive does not support RAR5 format (introduced 2013). This is a known limitation accepted for App Store compatibility.

**Detection Strategy**:
```
RAR4 magic bytes: 52 61 72 21 1A 07 00
RAR5 magic bytes: 52 61 72 21 1A 07 01 00

If RAR5 detected:
  Show message: "This comic uses RAR5 format which isn't currently supported.
                 Please convert to CBZ format for best compatibility."
```

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

### Phase 1A: Foundation

| # | Task | Priority | Estimated Complexity |
|---|------|----------|---------------------|
| 1 | Create Xcode project with SwiftUI template | High | Low |
| 2 | Configure project settings (bundle ID, deployment target) | High | Low |
| 3 | Set up folder structure as documented | High | Low |
| 4 | Implement basic NavigationSplitView layout | High | Medium |
| 5 | Create FileService for Documents folder access | High | Medium |
| 6 | Build LibraryView with file listing | High | Medium |
| 7 | Display image files (PNG, JPG, WEBP) | High | Low |
| 8 | Create basic ReaderView with single image | High | Medium |
| 9 | Implement swipe navigation between images | High | Medium |
| 10 | Add tap zones for page navigation | High | Low |

### Phase 1B: Archive Support

| # | Task | Priority | Estimated Complexity |
|---|------|----------|---------------------|
| 11 | Integrate libarchive into project | High | High |
| 12 | Create LibArchiveWrapper.swift bridging code | High | High |
| 13 | Implement ArchiveService protocol | High | Medium |
| 14 | Add ZIP/CBZ extraction | High | Medium |
| 15 | Add RAR4/CBR extraction | High | Medium |
| 16 | Implement RAR5 detection and error message | Medium | Low |
| 17 | Add 7z/CB7 extraction | Medium | Low |
| 18 | Create PDFService using PDFKit | High | Medium |
| 19 | Implement page caching system | High | Medium |
| 20 | Add extraction progress indicator | Medium | Low |

### Phase 1C: Reader Experience

| # | Task | Priority | Estimated Complexity |
|---|------|----------|---------------------|
| 21 | Implement ZoomableImageView with pinch-zoom | High | High |
| 22 | Add pan gesture while zoomed | High | Medium |
| 23 | Create auto-fit modes (width, height, screen) | High | Medium |
| 24 | Build ReaderControlsView overlay | High | Medium |
| 25 | Add page slider/scrubber | Medium | Medium |
| 26 | Implement full-screen mode | High | Low |
| 27 | Create ProgressService for persistence | High | Medium |
| 28 | Save reading progress on page change | High | Low |
| 29 | Restore last position on open | High | Low |
| 30 | Add bookmark functionality | Medium | Medium |

### Phase 1D: Secure Vault

| # | Task | Priority | Estimated Complexity |
|---|------|----------|---------------------|
| 31 | Create PasswordEntryView UI | High | Medium |
| 32 | Implement KeychainService | High | Medium |
| 33 | Add Face ID / Touch ID authentication | High | Medium |
| 34 | Create EncryptionService with AES-256-GCM | High | High |
| 35 | Implement vault manifest encryption | High | High |
| 36 | Build VaultView file browser | High | Medium |
| 37 | Add "Move to Vault" action | High | Medium |
| 38 | Add "Remove from Vault" action | High | Medium |
| 39 | Implement secure temporary file handling | High | Medium |
| 40 | Hide .vault folder from normal browsing | High | Low |

### Phase 1E: Polish & Testing

| # | Task | Priority | Estimated Complexity |
|---|------|----------|---------------------|
| 41 | Add app icon and launch screen | Medium | Low |
| 42 | Implement recent files list | Medium | Medium |
| 43 | Add pull-to-refresh in library | Low | Low |
| 44 | Create error handling and user feedback | High | Medium |
| 45 | Optimize memory usage for large files | High | High |
| 46 | Test on physical iPad device | High | - |
| 47 | Fix orientation handling issues | Medium | Medium |
| 48 | Performance testing with large libraries | Medium | Medium |

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

- [ ] Open CBZ file with 100+ pages
- [ ] Open CBR (RAR4) file
- [ ] Attempt to open RAR5 file (should show error)
- [ ] Open PDF with images
- [ ] Open folder of images
- [ ] Zoom and pan on detailed page
- [ ] Resume reading after app restart
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

---

## Notes

- Development environment: macOS with Xcode 15+
- Primary testing device: iPad
- This document should be updated as development progresses
- All file paths are relative to project root unless specified
