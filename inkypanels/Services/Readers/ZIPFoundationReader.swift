import Foundation
import ZIPFoundation

/// Archive reader for ZIP-based formats (CBZ, ZIP) using ZIPFoundation
actor ZIPFoundationReader: ArchiveReader {

    // MARK: - Properties

    let archiveURL: URL
    private let cacheDirectory: URL
    private var archive: Archive?
    private var cachedEntries: [ArchiveEntry]?

    // MARK: - Initialization

    init(url: URL) throws {
        self.archiveURL = url

        // Create unique cache directory for this archive
        let cacheBase = FileManager.default.temporaryDirectory
            .appendingPathComponent("inkypanels-extraction", isDirectory: true)
        let archiveHash = url.path.data(using: .utf8)?.base64EncodedString()
            .replacingOccurrences(of: "/", with: "_") ?? UUID().uuidString
        self.cacheDirectory = cacheBase.appendingPathComponent(archiveHash, isDirectory: true)

        // Create cache directory
        try FileManager.default.createDirectory(
            at: cacheDirectory,
            withIntermediateDirectories: true
        )

        // Open archive
        do {
            self.archive = try Archive(url: url, accessMode: .read)
        } catch {
            throw InkyPanelsError.archive(.invalidArchive)
        }
    }

    // MARK: - ArchiveReader Protocol

    func listEntries() async throws -> [ArchiveEntry] {
        // Return cached if available
        if let cached = cachedEntries {
            return cached
        }

        guard let archive = archive else {
            throw InkyPanelsError.archive(.invalidArchive)
        }

        var entries: [ArchiveEntry] = []
        var totalSize: UInt64 = 0

        for entry in archive {
            // Skip directories
            guard entry.type == .file else { continue }

            let path = entry.path

            // Security: validate path
            if let error = ArchiveLimits.validatePath(path) {
                // Log but skip malicious entries rather than failing entire archive
                continue
            }

            // Skip hidden/metadata files
            guard !ArchiveLimits.shouldSkipPath(path) else { continue }

            // Only include allowed image types
            guard ArchiveLimits.isAllowedExtension(path) else { continue }

            // Security: check entry size
            let size = UInt64(entry.uncompressedSize)
            guard size <= ArchiveLimits.maxUncompressedEntrySize else {
                // Skip oversized entries
                continue
            }

            totalSize += size

            // Security: check total size
            guard totalSize <= ArchiveLimits.maxTotalUncompressedSize else {
                throw InkyPanelsError.archive(.extractionFailed(underlying: NSError(
                    domain: "ZIPFoundationReader",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Archive total size exceeds limit"]
                )))
            }

            entries.append(ArchiveEntry(
                path: path,
                uncompressedSize: size,
                index: 0  // Will be set after sorting
            ))
        }

        // Security: check entry count
        guard entries.count <= ArchiveLimits.maxEntryCount else {
            throw ArchiveError.tooManyEntries(entries.count)
        }

        guard !entries.isEmpty else {
            throw InkyPanelsError.archive(.emptyArchive)
        }

        // Sort by natural order and assign indices
        let sorted = entries
            .sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
            .enumerated()
            .map { index, entry in
                ArchiveEntry(
                    path: entry.path,
                    uncompressedSize: entry.uncompressedSize,
                    index: index
                )
            }

        cachedEntries = sorted
        return sorted
    }

    func extractEntry(_ entry: ArchiveEntry) async throws -> URL {
        guard let archive = archive else {
            throw InkyPanelsError.archive(.invalidArchive)
        }

        // Find the entry in the archive
        guard let zipEntry = archive.first(where: { $0.path == entry.path }) else {
            throw InkyPanelsError.archive(.fileNotFound(entry.path))
        }

        // Destination file in cache directory
        let destinationURL = cacheDirectory.appendingPathComponent(entry.id)

        // Skip if already extracted
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            return destinationURL
        }

        // Extract to file
        do {
            _ = try archive.extract(zipEntry, to: destinationURL)
        } catch {
            throw InkyPanelsError.archive(.extractionFailed(underlying: error))
        }

        return destinationURL
    }

    static func canOpen(_ url: URL) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: url) else {
            return false
        }
        defer { try? handle.close() }

        guard let data = try? handle.read(upToCount: 4) else {
            return false
        }

        let bytes = [UInt8](data)

        // ZIP magic bytes: PK\x03\x04
        return bytes.starts(with: [0x50, 0x4B, 0x03, 0x04]) ||
               bytes.starts(with: [0x50, 0x4B, 0x05, 0x06]) ||  // Empty archive
               bytes.starts(with: [0x50, 0x4B, 0x07, 0x08])     // Spanned archive
    }

    // MARK: - Cleanup

    /// Remove all extracted files for this archive
    func cleanup() async {
        try? FileManager.default.removeItem(at: cacheDirectory)
    }

    deinit {
        // Cleanup on dealloc
        try? FileManager.default.removeItem(at: cacheDirectory)
    }
}
