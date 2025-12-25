import Foundation

/// Protocol for file system operations
protocol FileServiceProtocol: Sendable {
    /// List all comic files in a directory
    func listFiles(in directory: URL) async throws -> [ComicFile]

    /// Check if a file exists at the given URL
    func fileExists(at url: URL) -> Bool

    /// Move a file from source to destination
    func moveFile(from source: URL, to destination: URL) async throws

    /// Delete a file at the given URL
    func deleteFile(at url: URL) async throws

    /// Import a file from source to destination, returning the final URL
    func importFile(from source: URL, to destination: URL) async throws -> URL

    /// Detect the file type at the given URL
    func detectFileType(at url: URL) async throws -> ComicFileType

    /// Get the Documents directory URL
    var documentsDirectory: URL { get }

    /// Get the Comics directory URL (subdirectory of Documents)
    var comicsDirectory: URL { get }
}
