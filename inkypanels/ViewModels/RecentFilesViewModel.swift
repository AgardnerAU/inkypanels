import Foundation
import SwiftData

/// ViewModel for recent files
@MainActor
@Observable
final class RecentFilesViewModel {

    // MARK: - Published State

    var recentFiles: [(file: ComicFile, progress: ProgressRecord)] = []
    var isLoading: Bool = false

    // MARK: - Private Properties

    private var progressService: ProgressService?
    private let hideVaultFromRecentKey = Constants.UserDefaultsKey.hideVaultFromRecent

    // MARK: - Public Methods

    func configureService(modelContext: ModelContext) {
        self.progressService = ProgressService(modelContext: modelContext)
    }

    func loadRecentFiles() async {
        guard let progressService else { return }
        isLoading = true

        let hideVaultFiles = UserDefaults.standard.bool(forKey: hideVaultFromRecentKey)
        let records = await progressService.recentFiles(limit: 50)
        var loadedFiles: [(file: ComicFile, progress: ProgressRecord)] = []

        for record in records {
            let url = URL(fileURLWithPath: record.filePath)

            // Skip vault files if setting is enabled
            if hideVaultFiles && record.filePath.contains("/\(Constants.Paths.vaultFolder)/") {
                continue
            }

            // Check if file still exists
            guard FileManager.default.fileExists(atPath: record.filePath) else {
                continue
            }

            // Get file attributes
            guard let file = comicFile(from: url, progress: record) else {
                continue
            }

            loadedFiles.append((file: file, progress: record))
        }

        recentFiles = loadedFiles
        isLoading = false
    }

    func clearRecent(_ record: ProgressRecord) async {
        guard let progressService else { return }
        await progressService.deleteProgress(for: record.filePath)
        recentFiles.removeAll { $0.progress.filePath == record.filePath }
    }

    // MARK: - Private Methods

    private func comicFile(from url: URL, progress: ProgressRecord) -> ComicFile? {
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

            let fileId = UUID()
            return ComicFile(
                id: fileId,
                url: url,
                name: url.deletingPathExtension().lastPathComponent,
                fileType: fileType,
                fileSize: fileSize,
                modifiedDate: modifiedDate,
                pageCount: progress.totalPages,
                readingProgress: ReadingProgress(
                    comicId: fileId,
                    currentPage: progress.currentPage,
                    totalPages: progress.totalPages
                )
            )
        } catch {
            return nil
        }
    }
}
