import SwiftData
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

    /// Selected files for bulk operations
    var selectedFiles: Set<ComicFile.ID> = []

    /// Whether we're in selection mode
    var isSelecting: Bool = false

    /// Set of favourite file paths
    var favouritePaths: Set<String> = []

    // MARK: - Sort Order

    enum SortOrder: String, CaseIterable {
        case name = "Name"
        case dateModified = "Date Modified"
        case size = "Size"

        var label: String { rawValue }
    }

    // MARK: - Private Properties

    private let fileService: FileService
    private var favouriteService: FavouriteService?
    private let vaultService = VaultService()

    // MARK: - Initialization

    init(fileService: FileService = FileService()) {
        self.fileService = fileService
        self.currentDirectory = fileService.comicsDirectory
    }

    /// Configure favourite service (call from view with modelContext)
    func configureFavouriteService(modelContext: ModelContext) {
        self.favouriteService = FavouriteService(modelContext: modelContext)
    }

    // MARK: - Public Methods

    func loadFiles() async {
        isLoading = true
        error = nil

        do {
            let loadedFiles = try await fileService.listFiles(in: currentDirectory)
            files = sortFiles(loadedFiles)

            // Load favourite status for all files
            await loadFavouriteStatus()

            // Trigger background thumbnail generation for non-folder files
            let filesToThumbnail = files.filter { $0.fileType != .folder }
            ThumbnailView.generateThumbnailsInBackground(for: filesToThumbnail)
        } catch let err as InkyPanelsError {
            error = err
            files = []
        } catch {
            self.error = .fileSystem(.fileNotFound(currentDirectory))
            files = []
        }

        isLoading = false
    }

    private func loadFavouriteStatus() async {
        guard let favouriteService else { return }
        let paths = files.map { $0.url.path }
        favouritePaths = await favouriteService.favouriteStatus(for: paths)
    }

    // MARK: - Favourite Methods

    func isFavourite(_ file: ComicFile) -> Bool {
        favouritePaths.contains(file.url.path)
    }

    func toggleFavourite(_ file: ComicFile) async {
        guard let favouriteService else { return }
        let path = file.url.path

        // Optimistically update UI
        if favouritePaths.contains(path) {
            favouritePaths.remove(path)
        } else {
            favouritePaths.insert(path)
        }

        // Persist change
        await favouriteService.toggleFavourite(filePath: path)
    }

    // MARK: - Vault Methods

    func moveToVault(_ file: ComicFile) async {
        // Check if vault is set up and unlocked
        guard vaultService.isVaultSetUp else {
            // User needs to set up vault first - they'll need to navigate to Vault tab
            error = .vault(.vaultNotSetUp)
            return
        }

        guard await vaultService.checkUnlocked() else {
            // User needs to unlock vault first
            error = .vault(.vaultNotSetUp)
            return
        }

        do {
            try await vaultService.addFile(file)
            // Remove from current list
            files.removeAll { $0.id == file.id }
            selectedFiles.remove(file.id)
        } catch let vaultError as VaultError {
            error = .vault(vaultError)
        } catch {
            self.error = .vault(.encryptionFailed(underlying: error))
        }
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
        selectedFiles.remove(file.id)
    }

    func setSortOrder(_ order: SortOrder) {
        sortOrder = order
        files = sortFiles(files)
    }

    // MARK: - Selection Methods

    func toggleSelection() {
        isSelecting.toggle()
        if !isSelecting {
            selectedFiles.removeAll()
        }
    }

    func selectAll() {
        selectedFiles = Set(files.map { $0.id })
    }

    func deselectAll() {
        selectedFiles.removeAll()
    }

    func toggleFileSelection(_ file: ComicFile) {
        if selectedFiles.contains(file.id) {
            selectedFiles.remove(file.id)
        } else {
            selectedFiles.insert(file.id)
        }
    }

    func deleteSelected() async {
        let filesToDelete = files.filter { selectedFiles.contains($0.id) }

        for file in filesToDelete {
            do {
                try await fileService.deleteFile(at: file.url)
                files.removeAll { $0.id == file.id }
            } catch {
                // Continue deleting others even if one fails
            }
        }

        selectedFiles.removeAll()
        isSelecting = false
    }

    var selectedCount: Int {
        selectedFiles.count
    }

    var hasSelection: Bool {
        !selectedFiles.isEmpty
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
