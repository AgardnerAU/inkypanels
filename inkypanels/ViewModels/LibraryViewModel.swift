import SwiftUI

/// ViewModel for the library browser
@MainActor
@Observable
final class LibraryViewModel {

    // MARK: - Published State

    var files: [ComicFile] = []
    var isLoading: Bool = false
    var error: InkyPanelsError?
    var sortOrder: SortOrder = .name
    var currentDirectory: URL

    // MARK: - Sort Order

    enum SortOrder: String, CaseIterable {
        case name = "Name"
        case dateModified = "Date Modified"
        case size = "Size"

        var label: String { rawValue }
    }

    // MARK: - Private Properties

    private let fileService: FileService

    // MARK: - Initialization

    init(fileService: FileService = FileService()) {
        self.fileService = fileService
        self.currentDirectory = fileService.comicsDirectory
    }

    // MARK: - Public Methods

    func loadFiles() async {
        isLoading = true
        error = nil

        do {
            let loadedFiles = try await fileService.listFiles(in: currentDirectory)
            files = sortFiles(loadedFiles)
        } catch let err as InkyPanelsError {
            error = err
            files = []
        } catch {
            self.error = .fileSystem(.fileNotFound(currentDirectory))
            files = []
        }

        isLoading = false
    }

    func refresh() async {
        await loadFiles()
    }

    func navigateToFolder(_ folder: ComicFile) {
        guard folder.fileType == .folder else { return }
        currentDirectory = folder.url
        Task {
            await loadFiles()
        }
    }

    func navigateUp() {
        guard currentDirectory != fileService.comicsDirectory else { return }
        currentDirectory = currentDirectory.deletingLastPathComponent()
        Task {
            await loadFiles()
        }
    }

    func canNavigateUp() -> Bool {
        currentDirectory != fileService.comicsDirectory
    }

    func deleteFile(_ file: ComicFile) async throws {
        try await fileService.deleteFile(at: file.url)
        files.removeAll { $0.id == file.id }
    }

    func setSortOrder(_ order: SortOrder) {
        sortOrder = order
        files = sortFiles(files)
    }

    func pageCount(for file: ComicFile) async -> Int? {
        guard file.fileType.isArchive || file.fileType == .pdf else { return nil }

        do {
            let reader = try ArchiveReaderFactory.reader(for: file.url)
            let entries = try await reader.listEntries()
            return entries.count
        } catch {
            return nil
        }
    }

    // MARK: - Private Methods

    private func sortFiles(_ files: [ComicFile]) -> [ComicFile] {
        switch sortOrder {
        case .name:
            return files.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        case .dateModified:
            return files.sorted { $0.modifiedDate > $1.modifiedDate }
        case .size:
            return files.sorted { $0.fileSize > $1.fileSize }
        }
    }
}
