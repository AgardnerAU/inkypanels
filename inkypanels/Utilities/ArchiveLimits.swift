import Foundation

/// Security limits for archive extraction
/// These protect against zip bombs and malicious archives
enum ArchiveLimits {
    /// Maximum number of entries (pages) allowed in an archive
    static let maxEntryCount = 2000

    /// Maximum uncompressed size per entry (100MB)
    /// Protects against decompression bombs
    static let maxUncompressedEntrySize: UInt64 = 100 * 1024 * 1024

    /// Maximum total uncompressed size for entire archive (2GB)
    static let maxTotalUncompressedSize: UInt64 = 2 * 1024 * 1024 * 1024

    /// Allowed image file extensions (lowercase)
    static let allowedExtensions: Set<String> = [
        "jpg", "jpeg", "png", "gif", "webp", "tiff", "tif", "heic"
    ]

    /// Paths/prefixes to skip (macOS metadata, hidden files)
    static let ignoredPrefixes: [String] = [
        "__MACOSX",
        ".",
        "_"
    ]

    /// Validate an entry path for security issues
    /// - Returns: nil if valid, error message if invalid
    static func validatePath(_ path: String) -> String? {
        // Reject directory traversal
        if path.contains("..") {
            return "Path contains directory traversal"
        }

        // Reject absolute paths
        if path.hasPrefix("/") {
            return "Absolute paths not allowed"
        }

        // Reject backslash paths (Windows-style, potential exploit)
        if path.contains("\\") {
            return "Backslash paths not allowed"
        }

        return nil
    }

    /// Check if a path should be skipped (metadata, hidden files)
    static func shouldSkipPath(_ path: String) -> Bool {
        let fileName = URL(fileURLWithPath: path).lastPathComponent

        for prefix in ignoredPrefixes {
            if path.hasPrefix(prefix) || fileName.hasPrefix(prefix) {
                return true
            }
        }

        return false
    }

    /// Check if a file extension is an allowed image type
    static func isAllowedExtension(_ path: String) -> Bool {
        let ext = URL(fileURLWithPath: path).pathExtension.lowercased()
        return allowedExtensions.contains(ext)
    }
}
