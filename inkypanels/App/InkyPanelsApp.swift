import SwiftUI
import SwiftData

@main
struct InkyPanelsApp: App {
    @State private var appState = AppState.shared
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(Constants.UserDefaultsKey.clearRecentOnExit) private var clearRecentOnExit = false

    var sharedModelContainer: ModelContainer = {
        do {
            return try ModelContainer(for: ProgressRecord.self, FavouriteRecord.self)
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .onOpenURL { url in
                    handleOpenURL(url)
                }
        }
        .modelContainer(sharedModelContainer)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background && clearRecentOnExit {
                clearRecentFiles()
            }
        }
    }

    @MainActor
    private func clearRecentFiles() {
        let context = sharedModelContainer.mainContext
        let progressService = ProgressService(modelContext: context)
        Task {
            await progressService.clearAllProgress()
        }
    }

    private func handleOpenURL(_ url: URL) {
        // Start accessing security-scoped resource for files from outside the app sandbox
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing { url.stopAccessingSecurityScopedResource() }
        }

        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: url.path) else {
            return
        }

        do {
            // Import file to app's Documents folder so it appears in library
            let importedURL = try importFile(from: url)

            let attributes = try fileManager.attributesOfItem(atPath: importedURL.path)
            let fileSize = (attributes[.size] as? Int64) ?? 0
            let modifiedDate = (attributes[.modificationDate] as? Date) ?? Date()

            // Check if it's a directory to set correct file type
            var isDirectory: ObjCBool = false
            let fileType: ComicFileType
            if fileManager.fileExists(atPath: importedURL.path, isDirectory: &isDirectory),
               isDirectory.boolValue {
                fileType = .folder
            } else {
                fileType = ComicFileType(from: importedURL.pathExtension)
            }

            let comic = ComicFile(
                url: importedURL,
                name: importedURL.deletingPathExtension().lastPathComponent,
                fileType: fileType,
                fileSize: fileSize,
                modifiedDate: modifiedDate
            )

            // Set the file to open - ContentView will handle navigation
            appState.fileToOpen = comic
            // No need to track openedFileURL since file is now imported

        } catch {
            print("Failed to import file: \(error)")
        }
    }

    private func importFile(from sourceURL: URL) throws -> URL {
        let fileManager = FileManager.default

        // Get the app's Documents/Comics directory
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let comicsURL = documentsURL.appendingPathComponent(Constants.Paths.comicsFolder, isDirectory: true)

        // Create Comics directory if needed
        try fileManager.createDirectory(at: comicsURL, withIntermediateDirectories: true)

        // Destination URL
        let fileName = sourceURL.lastPathComponent
        var destinationURL = comicsURL.appendingPathComponent(fileName)

        // Handle duplicate filenames
        var counter = 1
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        let ext = sourceURL.pathExtension

        while fileManager.fileExists(atPath: destinationURL.path) {
            let newName: String
            if ext.isEmpty {
                // Folders don't have extensions - avoid trailing dot
                newName = "\(baseName) (\(counter))"
            } else {
                newName = "\(baseName) (\(counter)).\(ext)"
            }
            destinationURL = comicsURL.appendingPathComponent(newName)
            counter += 1
        }

        // Copy the file
        try fileManager.copyItem(at: sourceURL, to: destinationURL)

        return destinationURL
    }
}
