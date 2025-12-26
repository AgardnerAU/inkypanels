import CryptoKit
import Foundation

/// Represents a single entry (image) within an archive
/// This is metadata only - no image data is held in memory
struct ArchiveEntry: Identifiable, Sendable, Hashable {
    /// Unique identifier within the archive (SHA256 hash of path - 64 chars, filesystem-safe)
    let id: String

    /// Original path within the archive
    let path: String

    /// Just the filename portion
    let fileName: String

    /// Uncompressed size in bytes
    let uncompressedSize: UInt64

    /// Sorted position for page ordering (0-based)
    let index: Int

    init(path: String, uncompressedSize: UInt64, index: Int) {
        self.path = path
        self.fileName = URL(fileURLWithPath: path).lastPathComponent
        self.uncompressedSize = uncompressedSize
        self.index = index
        // Use SHA256 hash as stable ID (64 chars, always valid filename)
        let hash = SHA256.hash(data: Data(path.utf8))
        self.id = hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}
