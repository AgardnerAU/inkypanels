import Foundation

#if LIBARCHIVE_ENABLED

// MARK: - Real Implementation (when libarchive XCFramework is integrated)

/// Archive reader for RAR/7z formats using libarchive
actor LibArchiveReader: ArchiveReader {

    let archiveURL: URL
    private let cacheDirectory: URL

    init(url: URL) throws {
        self.archiveURL = url

        let cacheBase = FileManager.default.temporaryDirectory
            .appendingPathComponent("inkypanels-extraction", isDirectory: true)
        let archiveHash = url.path.data(using: .utf8)?.base64EncodedString()
            .replacingOccurrences(of: "/", with: "_") ?? UUID().uuidString
        self.cacheDirectory = cacheBase.appendingPathComponent(archiveHash, isDirectory: true)

        try FileManager.default.createDirectory(
            at: cacheDirectory,
            withIntermediateDirectories: true
        )

        // TODO: Initialize libarchive handle
        // let archive = archive_read_new()
        // archive_read_support_format_rar(archive)
        // archive_read_support_format_7zip(archive)
        // archive_read_support_filter_all(archive)
        // archive_read_open_filename(archive, url.path, 10240)
    }

    func listEntries() async throws -> [ArchiveEntry] {
        // TODO: Implement with libarchive
        // 1. Iterate with archive_read_next_header()
        // 2. Get path with archive_entry_pathname()
        // 3. Get size with archive_entry_size()
        // 4. Filter and sort as in ZIPFoundationReader
        fatalError("libarchive implementation pending")
    }

    func extractEntry(_ entry: ArchiveEntry) async throws -> URL {
        // TODO: Implement with libarchive
        // 1. Seek to entry
        // 2. Extract with archive_read_data() to temp file
        fatalError("libarchive implementation pending")
    }

    static func canOpen(_ url: URL) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: url) else {
            return false
        }
        defer { try? handle.close() }

        guard let data = try? handle.read(upToCount: 8) else {
            return false
        }

        let bytes = [UInt8](data)

        // RAR4: Rar!\x1a\x07\x00
        if bytes.starts(with: [0x52, 0x61, 0x72, 0x21, 0x1A, 0x07, 0x00]) {
            return true
        }

        // 7z: 7z\xbc\xaf\x27\x1c
        if bytes.starts(with: [0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C]) {
            return true
        }

        return false
    }
}

#else

// MARK: - Placeholder (when libarchive is not available)

/// Placeholder reader that returns unsupported format errors
/// Enable libarchive by adding LIBARCHIVE_ENABLED to Swift Active Compilation Conditions
actor LibArchiveReader: ArchiveReader {

    let archiveURL: URL

    init(url: URL) throws {
        self.archiveURL = url
        // Don't throw here - let listEntries() throw so error is surfaced properly
    }

    func listEntries() async throws -> [ArchiveEntry] {
        let ext = archiveURL.pathExtension.uppercased()
        throw InkyPanelsError.archive(.unsupportedFormat(ext))
    }

    func extractEntry(_ entry: ArchiveEntry) async throws -> URL {
        let ext = archiveURL.pathExtension.uppercased()
        throw InkyPanelsError.archive(.unsupportedFormat(ext))
    }

    static func canOpen(_ url: URL) -> Bool {
        // When libarchive is disabled, we can't open RAR/7z
        false
    }

    /// Check if libarchive support is compiled in
    static var isAvailable: Bool { false }
}

#endif

// MARK: - Shared Utilities

extension LibArchiveReader {
    /// Check if a file is RAR5 format (not supported even with libarchive)
    static func isRAR5(_ url: URL) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: url) else {
            return false
        }
        defer { try? handle.close() }

        guard let data = try? handle.read(upToCount: 8) else {
            return false
        }

        let bytes = [UInt8](data)
        // RAR5: Rar!\x1a\x07\x01\x00
        return bytes == [0x52, 0x61, 0x72, 0x21, 0x1A, 0x07, 0x01, 0x00]
    }
}
