import Foundation
import PDFKit

#if canImport(UIKit)
import UIKit
#endif

/// Archive reader for PDF documents using PDFKit
/// Renders PDF pages to images and caches them as files
actor PDFReader: ArchiveReader {

    // MARK: - Properties

    let archiveURL: URL
    private let cacheDirectory: URL
    private var document: PDFDocument?

    /// Resolution scale for rendering (2.0 = retina quality)
    private let renderScale: CGFloat = 2.0

    /// Maximum dimension to prevent memory issues
    private let maxDimension: CGFloat = 4096

    // MARK: - Initialization

    init(url: URL) throws {
        self.archiveURL = url

        let cacheBase = FileManager.default.temporaryDirectory
            .appendingPathComponent("inkypanels-extraction", isDirectory: true)
        let archiveHash = url.path.data(using: .utf8)?.base64EncodedString()
            .replacingOccurrences(of: "/", with: "_") ?? UUID().uuidString
        self.cacheDirectory = cacheBase.appendingPathComponent(archiveHash, isDirectory: true)

        try FileManager.default.createDirectory(
            at: cacheDirectory,
            withIntermediateDirectories: true
        )

        guard let doc = PDFDocument(url: url) else {
            throw InkyPanelsError.archive(.invalidArchive)
        }

        self.document = doc
    }

    // MARK: - ArchiveReader Protocol

    func listEntries() async throws -> [ArchiveEntry] {
        guard let document = document else {
            throw InkyPanelsError.archive(.invalidArchive)
        }

        let pageCount = document.pageCount

        guard pageCount > 0 else {
            throw InkyPanelsError.archive(.emptyArchive)
        }

        guard pageCount <= ArchiveLimits.maxEntryCount else {
            throw ArchiveError.tooManyEntries(pageCount)
        }

        return (0..<pageCount).map { index in
            let page = document.page(at: index)
            let bounds = page?.bounds(for: .mediaBox) ?? .zero
            let estimatedSize = UInt64(bounds.width * bounds.height * 4 * renderScale * renderScale)

            return ArchiveEntry(
                path: "page_\(index + 1).jpg",
                uncompressedSize: estimatedSize,
                index: index
            )
        }
    }

    func extractEntry(_ entry: ArchiveEntry) async throws -> URL {
        guard let document = document else {
            throw InkyPanelsError.archive(.invalidArchive)
        }

        let destinationURL = cacheDirectory.appendingPathComponent(entry.id)

        // Return cached if exists
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            return destinationURL
        }

        guard let page = document.page(at: entry.index) else {
            throw InkyPanelsError.reader(.pageLoadFailed(index: entry.index))
        }

        #if canImport(UIKit)
        guard let imageData = renderPageToData(page) else {
            throw InkyPanelsError.reader(.pageLoadFailed(index: entry.index))
        }

        try imageData.write(to: destinationURL, options: .atomic)
        return destinationURL
        #else
        throw InkyPanelsError.archive(.unsupportedFormat("PDF rendering requires UIKit"))
        #endif
    }

    static func canOpen(_ url: URL) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: url) else {
            return false
        }
        defer { try? handle.close() }

        guard let data = try? handle.read(upToCount: 4) else {
            return false
        }

        let bytes = [UInt8](data)
        // PDF magic: %PDF
        return bytes.starts(with: [0x25, 0x50, 0x44, 0x46])
    }

    // MARK: - Private Methods

    #if canImport(UIKit)
    private func renderPageToData(_ page: PDFPage) -> Data? {
        let bounds = page.bounds(for: .mediaBox)

        var scale = renderScale
        let maxBound = max(bounds.width, bounds.height) * scale
        if maxBound > maxDimension {
            scale = maxDimension / max(bounds.width, bounds.height)
        }

        let width = bounds.width * scale
        let height = bounds.height * scale

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))

        let image = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))

            context.cgContext.translateBy(x: 0, y: height)
            context.cgContext.scaleBy(x: scale, y: -scale)

            page.draw(with: .mediaBox, to: context.cgContext)
        }

        return image.jpegData(compressionQuality: 0.85)
    }
    #endif

    // MARK: - Cleanup

    func cleanup() async {
        try? FileManager.default.removeItem(at: cacheDirectory)
    }

    deinit {
        try? FileManager.default.removeItem(at: cacheDirectory)
    }
}
