import SwiftUI
import SwiftData

@main
struct InkyPanelsApp: App {
    @State private var appState = AppState.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .onOpenURL { url in
                    handleOpenURL(url)
                }
        }
        .modelContainer(for: [ProgressRecord.self, FavouriteRecord.self])
    }

    private func handleOpenURL(_ url: URL) {
        // Start accessing security-scoped resource for files from outside the app sandbox
        let accessing = url.startAccessingSecurityScopedResource()

        // Get file attributes
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: url.path) else {
            if accessing { url.stopAccessingSecurityScopedResource() }
            return
        }

        do {
            let attributes = try fileManager.attributesOfItem(atPath: url.path)
            let fileSize = (attributes[.size] as? Int64) ?? 0
            let modifiedDate = (attributes[.modificationDate] as? Date) ?? Date()

            // Determine file type
            let fileType = ComicFileType(from: url.pathExtension)

            // Create ComicFile
            let comic = ComicFile(
                url: url,
                name: url.deletingPathExtension().lastPathComponent,
                fileType: fileType,
                fileSize: fileSize,
                modifiedDate: modifiedDate
            )

            // Set the file to open - ContentView will handle navigation
            appState.fileToOpen = comic
            appState.openedFileURL = url

        } catch {
            if accessing { url.stopAccessingSecurityScopedResource() }
        }
    }
}
