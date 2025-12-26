import Foundation

/// Archive reader for folders containing image files
/// Treats each image in the folder as a page, sorted naturally by filename
actor FolderReader: ArchiveReader {

    // MARK: - Properties

    let archiveURL: URL
    private var cachedEntries: [ArchiveEntry]?

    // MARK: - Initialization

    init(url: URL) throws {
        self.archiveURL = url

        // Verify directory exists
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw InkyPanelsError.fileSystem(.fileNotFound(url))
        }
    }

    // MARK: - ArchiveReader Protocol

    func listEntries() async throws -> [ArchiveEntry] {
        if let cached = cachedEntries {
            return cached
        }

        let fileManager = FileManager.default

        // Get all items in directory
        let contents = try fileManager.contentsOfDirectory(
            at: archiveURL,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        // Filter to image files only
        var entries: [ArchiveEntry] = []

        for url in contents {
            // Skip directories
            let resourceValues = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
            guard resourceValues?.isRegularFile == true else { continue }

            // Check if it's an image extension
            let ext = url.pathExtension.lowercased()
            guard ImageReader.supportedExtensions.contains(ext) else { continue }

            let fileSize = (resourceValues?.fileSize).map(UInt64.init) ?? 0

            entries.append(ArchiveEntry(
                path: url.lastPathComponent,
                uncompressedSize: fileSize,
                index: 0  // Will be set after sorting
            ))
        }

        guard !entries.isEmpty else {
            throw InkyPanelsError.archive(.emptyArchive)
        }

        // Sort naturally by filename and assign indices
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
        // No extraction needed - return the full path to the image
        let imageURL = archiveURL.appendingPathComponent(entry.path)

        guard FileManager.default.fileExists(atPath: imageURL.path) else {
            throw InkyPanelsError.archive(.fileNotFound(entry.path))
        }

        return imageURL
    }

    static func canOpen(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            return false
        }
        return isDirectory.boolValue
    }
}
