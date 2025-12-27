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

        // Use enumerator for recursive traversal of all subdirectories
        // Collect URLs synchronously first (enumerator can't be iterated in async contexts in Swift 6)
        guard let enumerator = fileManager.enumerator(
            at: archiveURL,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw InkyPanelsError.fileSystem(.fileNotFound(archiveURL))
        }
        let allURLs = enumerator.allObjects.compactMap { $0 as? URL }

        // Filter to image files only
        var entries: [ArchiveEntry] = []

        for url in allURLs {
            // Skip directories
            let resourceValues = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
            guard resourceValues?.isRegularFile == true else { continue }

            // Check if it's an image extension
            let ext = url.pathExtension.lowercased()
            guard ImageReader.supportedExtensions.contains(ext) else { continue }

            let fileSize = (resourceValues?.fileSize).map(UInt64.init) ?? 0

            // Get relative path from archive root
            let relativePath = url.path.replacingOccurrences(
                of: archiveURL.path + "/",
                with: ""
            )

            entries.append(ArchiveEntry(
                path: relativePath,
                uncompressedSize: fileSize,
                index: 0  // Will be set after sorting
            ))
        }

        guard !entries.isEmpty else {
            throw InkyPanelsError.archive(.emptyArchive)
        }

        // Sort naturally by path and assign indices
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
