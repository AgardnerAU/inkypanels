import Foundation
import SwiftData

/// ViewModel for favourites tab
@MainActor
@Observable
final class FavouritesViewModel {

    // MARK: - Published State

    var favouriteFiles: [ComicFile] = []
    var isLoading: Bool = false

    // MARK: - Private Properties

    private var favouriteService: FavouriteService?

    // MARK: - Public Methods

    func configureService(modelContext: ModelContext) {
        self.favouriteService = FavouriteService(modelContext: modelContext)
    }

    func loadFavourites() async {
        guard let favouriteService else { return }
        isLoading = true

        let favouritePaths = await favouriteService.allFavourites()
        var loadedFiles: [ComicFile] = []

        for path in favouritePaths {
            let url = URL(fileURLWithPath: path)

            // Check if file still exists
            guard FileManager.default.fileExists(atPath: path) else {
                // Remove stale favourite
                await favouriteService.removeFavourite(filePath: path)
                continue
            }

            // Get file attributes
            guard let file = comicFile(from: url) else {
                continue
            }

            loadedFiles.append(file)
        }

        favouriteFiles = loadedFiles
        isLoading = false
    }

    func removeFavourite(_ file: ComicFile) async {
        guard let favouriteService else { return }
        await favouriteService.removeFavourite(filePath: file.url.path)
        favouriteFiles.removeAll { $0.id == file.id }
    }

    // MARK: - Private Methods

    private func comicFile(from url: URL) -> ComicFile? {
        let fileManager = FileManager.default

        do {
            let attributes = try fileManager.attributesOfItem(atPath: url.path)
            let fileSize = (attributes[.size] as? Int64) ?? 0
            let modifiedDate = (attributes[.modificationDate] as? Date) ?? Date()

            // Determine file type
            var isDirectory: ObjCBool = false
            fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory)

            let fileType: ComicFileType
            if isDirectory.boolValue {
                fileType = .folder
            } else {
                fileType = ComicFileType(from: url.pathExtension)
            }

            return ComicFile(
                url: url,
                name: url.deletingPathExtension().lastPathComponent,
                fileType: fileType,
                fileSize: fileSize,
                modifiedDate: modifiedDate
            )
        } catch {
            return nil
        }
    }
}
