import Foundation
import UniformTypeIdentifiers

/// Actor-based file system service for thread-safe file operations
actor FileService: FileServiceProtocol {

    // MARK: - Properties

    nonisolated var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    nonisolated var comicsDirectory: URL {
        documentsDirectory.appendingPathComponent(Constants.Paths.comicsFolder)
    }

    private let fileManager = FileManager.default

    // MARK: - Initialization

    init() {
        // Ensure comics directory exists
        Task {
            await ensureComicsDirectoryExists()
        }
    }

    // MARK: - FileServiceProtocol

    func listFiles(in directory: URL) async throws -> [ComicFile] {
        let contents = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [
                .fileSizeKey,
                .contentModificationDateKey,
                .isDirectoryKey
            ],
            options: [.skipsHiddenFiles]
        )

        var comicFiles: [ComicFile] = []

        for url in contents {
            do {
                let comicFile = try await createComicFile(from: url)
                if comicFile.fileType != .unknown {
                    comicFiles.append(comicFile)
                }
            } catch {
                // Skip files that can't be read
                continue
            }
        }

        return comicFiles.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    nonisolated func fileExists(at url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    func moveFile(from source: URL, to destination: URL) async throws {
        do {
            try fileManager.moveItem(at: source, to: destination)
        } catch {
            throw InkyPanelsError.fileSystem(.moveFailed(underlying: error))
        }
    }

    func deleteFile(at url: URL) async throws {
        do {
            try fileManager.removeItem(at: url)
        } catch {
            throw InkyPanelsError.fileSystem(.deletionFailed(underlying: error))
        }
    }

    func importFile(from source: URL, to destination: URL) async throws -> URL {
        var finalDestination = destination

        // Handle duplicate filenames
        if fileManager.fileExists(atPath: finalDestination.path) {
            finalDestination = generateUniqueFilename(for: destination)
        }

        do {
            try fileManager.copyItem(at: source, to: finalDestination)
            return finalDestination
        } catch {
            throw InkyPanelsError.fileSystem(.copyFailed(underlying: error))
        }
    }

    /// Lists comic files in the Documents root that can be imported into the Comics folder.
    /// Files transferred via Finder appear here and need to be moved to the Comics directory.
    func listImportableFiles() async throws -> [ComicFile] {
        let contents = try fileManager.contentsOfDirectory(
            at: documentsDirectory,
            includingPropertiesForKeys: [
                .fileSizeKey,
                .contentModificationDateKey,
                .isDirectoryKey
            ],
            options: [.skipsHiddenFiles]
        )

        var importableFiles: [ComicFile] = []

        for url in contents {
            // Skip the Comics folder and other app directories
            let filename = url.lastPathComponent
            if filename == Constants.Paths.comicsFolder ||
               filename == "Thumbnails" ||
               filename.hasPrefix(".") {
                continue
            }

            do {
                let comicFile = try await createComicFile(from: url)
                // Only include supported file types (not unknown)
                if comicFile.fileType != .unknown {
                    importableFiles.append(comicFile)
                }
            } catch {
                // Skip files that can't be read
                continue
            }
        }

        return importableFiles.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Moves a file from Documents root into the Comics directory
    func importFileToLibrary(from source: URL) async throws -> URL {
        let destination = comicsDirectory.appendingPathComponent(source.lastPathComponent)
        var finalDestination = destination

        // Handle duplicate filenames
        if fileManager.fileExists(atPath: finalDestination.path) {
            finalDestination = generateUniqueFilename(for: destination)
        }

        do {
            // Move instead of copy since the file is already in our sandbox
            try fileManager.moveItem(at: source, to: finalDestination)
            return finalDestination
        } catch {
            throw InkyPanelsError.fileSystem(.moveFailed(underlying: error))
        }
    }

    func detectFileType(at url: URL) async throws -> ComicFileType {
        // First, try to detect by magic bytes
        if let data = try? Data(contentsOf: url, options: .mappedIfSafe) {
            let headerData = data.prefix(12)

            // Check for RAR5 first (unsupported)
            if FileTypeDetector.isRAR5(data: headerData) {
                throw InkyPanelsError.archive(.rar5NotSupported)
            }

            if let detectedType = FileTypeDetector.detectType(from: headerData) {
                return mapToComicType(detectedType, extension: url.pathExtension)
            }
        }

        // Fall back to file extension
        return ComicFileType(from: url.pathExtension)
    }

    // MARK: - Private Methods

    private func ensureComicsDirectoryExists() {
        if !fileManager.fileExists(atPath: comicsDirectory.path) {
            try? fileManager.createDirectory(at: comicsDirectory, withIntermediateDirectories: true)
        }
    }

    private func createComicFile(from url: URL) async throws -> ComicFile {
        let resourceValues = try url.resourceValues(forKeys: [
            .fileSizeKey,
            .contentModificationDateKey,
            .isDirectoryKey
        ])

        let isDirectory = resourceValues.isDirectory ?? false
        let fileSize = Int64(resourceValues.fileSize ?? 0)
        let modifiedDate = resourceValues.contentModificationDate ?? Date()

        let fileType: ComicFileType
        if isDirectory {
            fileType = .folder
        } else {
            fileType = try await detectFileType(at: url)
        }

        return ComicFile(
            url: url,
            name: url.deletingPathExtension().lastPathComponent,
            fileType: fileType,
            fileSize: fileSize,
            modifiedDate: modifiedDate
        )
    }

    private func mapToComicType(_ detectedType: ComicFileType, extension ext: String) -> ComicFileType {
        // Map generic archive types to comic types based on extension
        let lowercaseExt = ext.lowercased()

        switch (detectedType, lowercaseExt) {
        case (.zip, "cbz"):
            return .cbz
        case (.rar, "cbr"):
            return .cbr
        case (.sevenZip, "cb7"):
            return .cb7
        default:
            return detectedType
        }
    }

    private func generateUniqueFilename(for url: URL) -> URL {
        let directory = url.deletingLastPathComponent()
        let filename = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension

        var counter = 1
        var newURL: URL

        repeat {
            let newFilename = "\(filename) (\(counter)).\(ext)"
            newURL = directory.appendingPathComponent(newFilename)
            counter += 1
        } while fileManager.fileExists(atPath: newURL.path)

        return newURL
    }
}
