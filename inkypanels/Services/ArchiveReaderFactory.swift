import Foundation

/// Factory for creating the appropriate archive reader based on file type
enum ArchiveReaderFactory {

    /// Create a reader for the given archive URL
    /// Routes to the appropriate backend based on file extension and magic bytes
    static func reader(for url: URL) throws -> any ArchiveReader {
        let ext = url.pathExtension.lowercased()

        switch ext {
        // ZIP-based formats
        case "cbz", "zip":
            return try ZIPFoundationReader(url: url)

        // RAR-based formats
        case "cbr", "rar":
            // Check for RAR5 first (not supported even with libarchive)
            if LibArchiveReader.isRAR5(url) {
                throw InkyPanelsError.archive(.rar5NotSupported)
            }
            return try LibArchiveReader(url: url)

        // 7-Zip formats
        case "cb7", "7z":
            return try LibArchiveReader(url: url)

        // PDF documents
        case "pdf":
            return try PDFReader(url: url)

        default:
            throw InkyPanelsError.archive(.unsupportedFormat(ext.uppercased()))
        }
    }

    /// Check if a format is supported (considering libarchive availability)
    static func isFormatSupported(_ ext: String) -> Bool {
        let normalized = ext.lowercased()

        switch normalized {
        case "cbz", "zip", "pdf":
            return true

        case "cbr", "rar", "cb7", "7z":
            #if LIBARCHIVE_ENABLED
            return true
            #else
            return false
            #endif

        default:
            return false
        }
    }

    /// List of currently supported formats for UI display
    static var supportedFormats: [String] {
        var formats = ["CBZ", "ZIP", "PDF"]
        #if LIBARCHIVE_ENABLED
        formats += ["CBR", "RAR", "CB7", "7Z"]
        #endif
        return formats
    }

    /// User-friendly description of supported formats
    static var supportedFormatsDescription: String {
        supportedFormats.joined(separator: ", ")
    }
}
