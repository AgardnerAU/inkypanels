import Foundation

/// Represents a comic file or folder in the library
struct ComicFile: Identifiable, Hashable, Sendable {
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

    init(
        id: UUID = UUID(),
        url: URL,
        name: String,
        fileType: ComicFileType,
        fileSize: Int64,
        modifiedDate: Date,
        pageCount: Int? = nil,
        readingProgress: ReadingProgress? = nil,
        rating: Int? = nil,
        isInVault: Bool = false
    ) {
        self.id = id
        self.url = url
        self.name = name
        self.fileType = fileType
        self.fileSize = fileSize
        self.modifiedDate = modifiedDate
        self.pageCount = pageCount
        self.readingProgress = readingProgress
        self.rating = rating
        self.isInVault = isInVault
    }
}

/// Supported comic and image file types
enum ComicFileType: String, CaseIterable, Sendable {
    // Comic archives
    case cbz
    case cbr
    case cb7
    case cba

    // Generic archives
    case zip
    case rar
    case sevenZip = "7z"

    // Documents
    case pdf

    // Image formats
    case png
    case jpg
    case jpeg
    case webp
    case tiff
    case tif
    case gif
    case heic

    // Special
    case folder
    case unknown

    /// Whether this type is a comic archive format
    var isComicArchive: Bool {
        switch self {
        case .cbz, .cbr, .cb7, .cba:
            return true
        default:
            return false
        }
    }

    /// Whether this type is any kind of archive
    var isArchive: Bool {
        switch self {
        case .cbz, .cbr, .cb7, .cba, .zip, .rar, .sevenZip:
            return true
        default:
            return false
        }
    }

    /// Whether this type is a supported image format
    var isImage: Bool {
        switch self {
        case .png, .jpg, .jpeg, .webp, .tiff, .tif, .gif, .heic:
            return true
        default:
            return false
        }
    }

    /// File extension for this type
    var fileExtension: String {
        switch self {
        case .sevenZip:
            return "7z"
        default:
            return rawValue
        }
    }

    /// Initialize from a file extension
    init(from extension: String) {
        let ext = `extension`.lowercased()
        switch ext {
        case "cbz": self = .cbz
        case "cbr": self = .cbr
        case "cb7": self = .cb7
        case "cba": self = .cba
        case "zip": self = .zip
        case "rar": self = .rar
        case "7z": self = .sevenZip
        case "pdf": self = .pdf
        case "png": self = .png
        case "jpg": self = .jpg
        case "jpeg": self = .jpeg
        case "webp": self = .webp
        case "tiff": self = .tiff
        case "tif": self = .tif
        case "gif": self = .gif
        case "heic": self = .heic
        default: self = .unknown
        }
    }
}

/// Supported file format definitions
enum SupportedFormat {
    static let images: Set<String> = ["png", "jpg", "jpeg", "webp", "tiff", "tif", "gif", "heic"]
    static let comics: Set<String> = ["cbz", "cbr", "cb7", "cba"]
    static let archives: Set<String> = ["zip", "rar", "7z"]
    static let documents: Set<String> = ["pdf"]

    static var all: Set<String> {
        images.union(comics).union(archives).union(documents)
    }
}
