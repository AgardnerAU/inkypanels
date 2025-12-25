import Foundation
import ZIPFoundation

/// Actor-based archive extraction service
actor ArchiveService: ArchiveServiceProtocol {

    // MARK: - Private Properties

    private let supportedImageExtensions: Set<String> = [
        "jpg", "jpeg", "png", "gif", "webp", "tiff", "tif", "heic"
    ]

    // MARK: - ArchiveServiceProtocol

    func extractPages(from url: URL) async throws -> [ComicPage] {
        let archive: Archive
        do {
            archive = try Archive(url: url, accessMode: .read)
        } catch {
            throw InkyPanelsError.archive(.invalidArchive)
        }

        let imageEntries = sortedImageEntries(from: archive)

        guard !imageEntries.isEmpty else {
            throw InkyPanelsError.archive(.emptyArchive)
        }

        var pages: [ComicPage] = []

        for (index, entry) in imageEntries.enumerated() {
            var imageData = Data()

            do {
                _ = try archive.extract(entry) { data in
                    imageData.append(data)
                }

                let page = ComicPage(
                    index: index,
                    fileName: URL(fileURLWithPath: entry.path).lastPathComponent,
                    imageData: imageData
                )
                pages.append(page)
            } catch {
                // Log error but continue with other pages
                continue
            }
        }

        guard !pages.isEmpty else {
            throw InkyPanelsError.archive(.extractionFailed(underlying: NSError(
                domain: "ArchiveService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to extract any pages"]
            )))
        }

        return pages
    }

    func extractPage(at index: Int, from url: URL) async throws -> ComicPage {
        let archive: Archive
        do {
            archive = try Archive(url: url, accessMode: .read)
        } catch {
            throw InkyPanelsError.archive(.invalidArchive)
        }

        let imageEntries = sortedImageEntries(from: archive)

        guard index >= 0 && index < imageEntries.count else {
            throw InkyPanelsError.reader(.invalidPageIndex(index))
        }

        let entry = imageEntries[index]
        var imageData = Data()

        do {
            _ = try archive.extract(entry) { data in
                imageData.append(data)
            }
        } catch {
            throw InkyPanelsError.archive(.extractionFailed(underlying: error))
        }

        return ComicPage(
            index: index,
            fileName: URL(fileURLWithPath: entry.path).lastPathComponent,
            imageData: imageData
        )
    }

    func pageCount(for url: URL) async throws -> Int {
        let archive: Archive
        do {
            archive = try Archive(url: url, accessMode: .read)
        } catch {
            throw InkyPanelsError.archive(.invalidArchive)
        }

        return sortedImageEntries(from: archive).count
    }

    func extractCoverImage(from url: URL) async throws -> Data {
        let firstPage = try await extractPage(at: 0, from: url)

        guard let imageData = firstPage.imageData else {
            throw InkyPanelsError.reader(.pageLoadFailed(index: 0))
        }

        return imageData
    }

    func pageMetadata(for url: URL) async throws -> [ComicPageMetadata] {
        let archive: Archive
        do {
            archive = try Archive(url: url, accessMode: .read)
        } catch {
            throw InkyPanelsError.archive(.invalidArchive)
        }

        let imageEntries = sortedImageEntries(from: archive)

        return imageEntries.enumerated().map { index, entry in
            ComicPageMetadata(
                index: index,
                fileName: URL(fileURLWithPath: entry.path).lastPathComponent,
                fileSize: Int64(entry.uncompressedSize)
            )
        }
    }

    // MARK: - Private Methods

    private func sortedImageEntries(from archive: Archive) -> [Entry] {
        archive
            .filter { entry in
                // Skip directories
                guard entry.type == .file else { return false }

                // Skip hidden files and macOS metadata
                let path = entry.path
                guard !path.hasPrefix("__MACOSX") else { return false }
                guard !URL(fileURLWithPath: path).lastPathComponent.hasPrefix(".") else { return false }

                // Check if it's an image file
                let ext = URL(fileURLWithPath: path).pathExtension.lowercased()
                return supportedImageExtensions.contains(ext)
            }
            .sorted { entry1, entry2 in
                // Natural sort for proper page ordering (page1, page2, page10 instead of page1, page10, page2)
                entry1.path.localizedStandardCompare(entry2.path) == .orderedAscending
            }
    }
}
