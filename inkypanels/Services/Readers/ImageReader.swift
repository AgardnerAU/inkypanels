import Foundation

/// Archive reader for single image files
/// Wraps a single image as a one-page "archive" for consistent handling
actor ImageReader: ArchiveReader {

    // MARK: - Properties

    let archiveURL: URL

    // MARK: - Initialization

    init(url: URL) throws {
        self.archiveURL = url

        // Verify file exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw InkyPanelsError.fileSystem(.fileNotFound(url))
        }
    }

    // MARK: - ArchiveReader Protocol

    func listEntries() async throws -> [ArchiveEntry] {
        let attributes = try FileManager.default.attributesOfItem(atPath: archiveURL.path)
        let fileSize = (attributes[.size] as? UInt64) ?? 0

        return [
            ArchiveEntry(
                path: archiveURL.lastPathComponent,
                uncompressedSize: fileSize,
                index: 0
            )
        ]
    }

    func extractEntry(_ entry: ArchiveEntry) async throws -> URL {
        // No extraction needed - return the original file URL
        return archiveURL
    }

    static func canOpen(_ url: URL) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: url) else {
            return false
        }
        defer { try? handle.close() }

        guard let data = try? handle.read(upToCount: 12) else {
            return false
        }

        let bytes = [UInt8](data)

        // JPEG: FFD8FF
        if bytes.starts(with: [0xFF, 0xD8, 0xFF]) {
            return true
        }

        // PNG: 89504E47
        if bytes.starts(with: [0x89, 0x50, 0x4E, 0x47]) {
            return true
        }

        // GIF: 474946
        if bytes.starts(with: [0x47, 0x49, 0x46]) {
            return true
        }

        // WebP: RIFF....WEBP
        if bytes.count >= 12 &&
           bytes.starts(with: [0x52, 0x49, 0x46, 0x46]) &&
           bytes[8...11] == [0x57, 0x45, 0x42, 0x50] {
            return true
        }

        // TIFF: 49492A00 or 4D4D002A
        if bytes.starts(with: [0x49, 0x49, 0x2A, 0x00]) ||
           bytes.starts(with: [0x4D, 0x4D, 0x00, 0x2A]) {
            return true
        }

        // HEIC/HEIF: Check for ftyp box with heic/heif/mif1 brand
        if bytes.count >= 12 &&
           bytes[4...7] == [0x66, 0x74, 0x79, 0x70] {  // "ftyp"
            return true
        }

        return false
    }

    // MARK: - Supported Extensions

    static let supportedExtensions: Set<String> = [
        "jpg", "jpeg", "png", "gif", "webp", "tiff", "tif", "heic", "heif"
    ]

    static func isImageExtension(_ ext: String) -> Bool {
        supportedExtensions.contains(ext.lowercased())
    }
}
