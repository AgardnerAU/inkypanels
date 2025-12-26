import Foundation

/// Protocol for streaming archive extraction
/// Implementations extract to temp files rather than holding data in memory
protocol ArchiveReader: AnyObject, Sendable {
    /// The archive URL this reader was opened with
    var archiveURL: URL { get }

    /// List all image entries, filtered and sorted for reading order
    /// This only reads metadata - no decompression occurs
    func listEntries() async throws -> [ArchiveEntry]

    /// Extract a single entry to a temporary file
    /// Returns the URL of the extracted file
    /// The caller is responsible for cache management
    func extractEntry(_ entry: ArchiveEntry) async throws -> URL

    /// Check if this reader type can open the given archive
    /// Uses magic bytes detection, not file extension
    static func canOpen(_ url: URL) -> Bool
}

/// Errors specific to archive reading operations
extension ArchiveError {
    /// Entry path contains directory traversal attack
    static func maliciousPath(_ path: String) -> ArchiveError {
        .extractionFailed(underlying: NSError(
            domain: "ArchiveReader",
            code: -100,
            userInfo: [NSLocalizedDescriptionKey: "Malicious path detected: \(path)"]
        ))
    }

    /// Entry exceeds size limits
    static func entryTooLarge(_ path: String, _ size: UInt64) -> ArchiveError {
        .extractionFailed(underlying: NSError(
            domain: "ArchiveReader",
            code: -101,
            userInfo: [NSLocalizedDescriptionKey: "Entry too large: \(path) (\(size) bytes)"]
        ))
    }

    /// Archive has too many entries
    static func tooManyEntries(_ count: Int) -> ArchiveError {
        .extractionFailed(underlying: NSError(
            domain: "ArchiveReader",
            code: -102,
            userInfo: [NSLocalizedDescriptionKey: "Archive has too many entries: \(count)"]
        ))
    }
}
