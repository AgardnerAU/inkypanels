import CryptoKit
import Foundation
import ZIPFoundation

/// Archive reader for ePub e-book format
/// ePub files are ZIP archives with a specific structure containing XHTML content and images
actor EPubReader: ArchiveReader {

    // MARK: - Properties

    let archiveURL: URL
    private let cacheDirectory: URL
    private var archive: Archive?
    private var cachedEntries: [ArchiveEntry]?
    private var opfBasePath: String = ""

    // MARK: - Initialization

    init(url: URL) throws {
        self.archiveURL = url

        // Create unique cache directory for this archive using SHA256 hash
        let cacheBase = FileManager.default.temporaryDirectory
            .appendingPathComponent("inkypanels-extraction", isDirectory: true)
        let hash = SHA256.hash(data: Data(url.path.utf8))
        let archiveHash = hash.compactMap { String(format: "%02x", $0) }.joined()
        self.cacheDirectory = cacheBase.appendingPathComponent(archiveHash, isDirectory: true)

        // Create cache directory
        try FileManager.default.createDirectory(
            at: cacheDirectory,
            withIntermediateDirectories: true
        )

        // Open archive
        do {
            self.archive = try Archive(url: url, accessMode: .read, pathEncoding: nil)
        } catch {
            throw InkyPanelsError.archive(.invalidArchive)
        }
    }

    // MARK: - ArchiveReader Protocol

    func listEntries() async throws -> [ArchiveEntry] {
        // Return cached if available
        if let cached = cachedEntries {
            return cached
        }

        guard let archive = archive else {
            throw InkyPanelsError.archive(.invalidArchive)
        }

        // Step 1: Find and parse container.xml to get OPF path
        let opfPath = try findOPFPath(in: archive)

        // Store base path for resolving relative paths in OPF
        opfBasePath = URL(fileURLWithPath: opfPath).deletingLastPathComponent().path
        if !opfBasePath.isEmpty && !opfBasePath.hasSuffix("/") {
            opfBasePath += "/"
        }

        // Step 2: Parse OPF to get manifest and spine
        let (manifest, spine) = try parseOPF(at: opfPath, in: archive)

        // Step 3: Collect images in reading order
        var entries: [ArchiveEntry] = []
        var seenPaths = Set<String>()
        var totalSize: UInt64 = 0

        // First, get images directly referenced in spine (for fixed-layout ePubs)
        for itemRef in spine {
            guard let item = manifest[itemRef] else { continue }

            if isImageMediaType(item.mediaType) {
                let fullPath = resolvePath(item.href)
                if !seenPaths.contains(fullPath) {
                    if let entry = createEntry(for: fullPath, in: archive, index: entries.count) {
                        totalSize += entry.uncompressedSize
                        guard totalSize <= ArchiveLimits.maxTotalUncompressedSize else {
                            break
                        }
                        entries.append(entry)
                        seenPaths.insert(fullPath)
                    }
                }
            } else if isXHTMLMediaType(item.mediaType) {
                // Parse XHTML for image references
                let xhtmlImages = try extractImagesFromXHTML(at: item.href, in: archive)
                for imagePath in xhtmlImages {
                    let fullPath = resolvePath(imagePath, relativeTo: item.href)
                    if !seenPaths.contains(fullPath) {
                        if let entry = createEntry(for: fullPath, in: archive, index: entries.count) {
                            totalSize += entry.uncompressedSize
                            guard totalSize <= ArchiveLimits.maxTotalUncompressedSize else {
                                break
                            }
                            entries.append(entry)
                            seenPaths.insert(fullPath)
                        }
                    }
                }
            }
        }

        // If no images found in spine, fall back to all images in manifest
        if entries.isEmpty {
            for (_, item) in manifest {
                if isImageMediaType(item.mediaType) {
                    let fullPath = resolvePath(item.href)
                    if !seenPaths.contains(fullPath) {
                        if let entry = createEntry(for: fullPath, in: archive, index: entries.count) {
                            totalSize += entry.uncompressedSize
                            guard totalSize <= ArchiveLimits.maxTotalUncompressedSize else {
                                break
                            }
                            entries.append(entry)
                            seenPaths.insert(fullPath)
                        }
                    }
                }
            }

            // Sort alphabetically if using fallback
            entries = entries
                .sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
                .enumerated()
                .map { index, entry in
                    ArchiveEntry(
                        path: entry.path,
                        uncompressedSize: entry.uncompressedSize,
                        index: index
                    )
                }
        }

        // Security: check entry count
        guard entries.count <= ArchiveLimits.maxEntryCount else {
            throw ArchiveError.tooManyEntries(entries.count)
        }

        guard !entries.isEmpty else {
            throw InkyPanelsError.archive(.emptyArchive)
        }

        cachedEntries = entries
        return entries
    }

    func extractEntry(_ entry: ArchiveEntry) async throws -> URL {
        guard let archive = archive else {
            throw InkyPanelsError.archive(.invalidArchive)
        }

        // Find the entry in the archive
        guard let zipEntry = archive.first(where: { $0.path == entry.path }) else {
            throw InkyPanelsError.archive(.fileNotFound(entry.path))
        }

        // Destination file in cache directory
        let destinationURL = cacheDirectory.appendingPathComponent(entry.id)

        // Skip if already extracted
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            return destinationURL
        }

        // Extract to file
        do {
            _ = try archive.extract(zipEntry, to: destinationURL)
        } catch {
            throw InkyPanelsError.archive(.extractionFailed(underlying: error))
        }

        return destinationURL
    }

    static func canOpen(_ url: URL) -> Bool {
        // ePub files are ZIP archives
        guard let handle = try? FileHandle(forReadingFrom: url) else {
            return false
        }
        defer { try? handle.close() }

        guard let data = try? handle.read(upToCount: 4) else {
            return false
        }

        let bytes = [UInt8](data)

        // Check for ZIP magic bytes
        return bytes.starts(with: [0x50, 0x4B, 0x03, 0x04])
    }

    // MARK: - Private Methods

    /// Find the OPF file path from container.xml
    private func findOPFPath(in archive: Archive) throws -> String {
        let containerPath = "META-INF/container.xml"

        guard let containerEntry = archive.first(where: { $0.path == containerPath }) else {
            throw InkyPanelsError.archive(.invalidArchive)
        }

        // Extract container.xml to get its content
        var containerData = Data()
        do {
            _ = try archive.extract(containerEntry) { data in
                containerData.append(data)
            }
        } catch {
            throw InkyPanelsError.archive(.extractionFailed(underlying: error))
        }

        guard let containerXML = String(data: containerData, encoding: .utf8) else {
            throw InkyPanelsError.archive(.invalidArchive)
        }

        // Parse container.xml to find rootfile path
        // Looking for: <rootfile full-path="OEBPS/content.opf" .../>
        guard let opfPath = extractAttribute(named: "full-path", from: "rootfile", in: containerXML) else {
            throw InkyPanelsError.archive(.invalidArchive)
        }

        return opfPath
    }

    /// Parse the OPF file to get manifest and spine
    private func parseOPF(at path: String, in archive: Archive) throws -> (manifest: [String: ManifestItem], spine: [String]) {
        guard let opfEntry = archive.first(where: { $0.path == path }) else {
            throw InkyPanelsError.archive(.fileNotFound(path))
        }

        var opfData = Data()
        do {
            _ = try archive.extract(opfEntry) { data in
                opfData.append(data)
            }
        } catch {
            throw InkyPanelsError.archive(.extractionFailed(underlying: error))
        }

        guard let opfXML = String(data: opfData, encoding: .utf8) else {
            throw InkyPanelsError.archive(.invalidArchive)
        }

        // Parse manifest items
        var manifest: [String: ManifestItem] = [:]
        let manifestItems = extractManifestItems(from: opfXML)
        for item in manifestItems {
            manifest[item.id] = item
        }

        // Parse spine order
        let spine = extractSpineOrder(from: opfXML)

        return (manifest, spine)
    }

    /// Extract manifest items from OPF XML
    private func extractManifestItems(from xml: String) -> [ManifestItem] {
        var items: [ManifestItem] = []

        // Simple regex to find <item> elements
        // Pattern: <item id="..." href="..." media-type="..."/>
        let pattern = #"<item[^>]+id\s*=\s*["\']([^"\']+)["\'][^>]+href\s*=\s*["\']([^"\']+)["\'][^>]+media-type\s*=\s*["\']([^"\']+)["\'][^>]*/>"#
        let altPattern = #"<item[^>]+href\s*=\s*["\']([^"\']+)["\'][^>]+id\s*=\s*["\']([^"\']+)["\'][^>]+media-type\s*=\s*["\']([^"\']+)["\'][^>]*/>"#

        if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
            let range = NSRange(xml.startIndex..., in: xml)
            let matches = regex.matches(in: xml, options: [], range: range)

            for match in matches {
                if let idRange = Range(match.range(at: 1), in: xml),
                   let hrefRange = Range(match.range(at: 2), in: xml),
                   let mediaTypeRange = Range(match.range(at: 3), in: xml) {
                    let id = String(xml[idRange])
                    let href = String(xml[hrefRange]).removingPercentEncoding ?? String(xml[hrefRange])
                    let mediaType = String(xml[mediaTypeRange])
                    items.append(ManifestItem(id: id, href: href, mediaType: mediaType))
                }
            }
        }

        // Try alternative pattern if first didn't match
        if items.isEmpty, let regex = try? NSRegularExpression(pattern: altPattern, options: [.caseInsensitive]) {
            let range = NSRange(xml.startIndex..., in: xml)
            let matches = regex.matches(in: xml, options: [], range: range)

            for match in matches {
                if let hrefRange = Range(match.range(at: 1), in: xml),
                   let idRange = Range(match.range(at: 2), in: xml),
                   let mediaTypeRange = Range(match.range(at: 3), in: xml) {
                    let id = String(xml[idRange])
                    let href = String(xml[hrefRange]).removingPercentEncoding ?? String(xml[hrefRange])
                    let mediaType = String(xml[mediaTypeRange])
                    items.append(ManifestItem(id: id, href: href, mediaType: mediaType))
                }
            }
        }

        // Fallback: more flexible parsing
        if items.isEmpty {
            items = extractManifestItemsFlexible(from: xml)
        }

        return items
    }

    /// More flexible manifest item extraction
    private func extractManifestItemsFlexible(from xml: String) -> [ManifestItem] {
        var items: [ManifestItem] = []

        // Find all <item .../> or <item ...>...</item> tags
        let itemPattern = #"<item\s+([^>]+)/?>|<item\s+([^>]+)>.*?</item>"#
        guard let regex = try? NSRegularExpression(pattern: itemPattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return items
        }

        let range = NSRange(xml.startIndex..., in: xml)
        let matches = regex.matches(in: xml, options: [], range: range)

        for match in matches {
            let attributeRange = match.range(at: 1).location != NSNotFound ? match.range(at: 1) : match.range(at: 2)
            guard let attrRange = Range(attributeRange, in: xml) else { continue }

            let attributes = String(xml[attrRange])

            if let id = extractAttributeValue(named: "id", from: attributes),
               let href = extractAttributeValue(named: "href", from: attributes),
               let mediaType = extractAttributeValue(named: "media-type", from: attributes) {
                let decodedHref = href.removingPercentEncoding ?? href
                items.append(ManifestItem(id: id, href: decodedHref, mediaType: mediaType))
            }
        }

        return items
    }

    /// Extract spine order (list of idref values)
    private func extractSpineOrder(from xml: String) -> [String] {
        var spine: [String] = []

        // Find <itemref idref="..."/>
        let pattern = #"<itemref[^>]+idref\s*=\s*["\']([^"\']+)["\'][^>]*/>"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
            let range = NSRange(xml.startIndex..., in: xml)
            let matches = regex.matches(in: xml, options: [], range: range)

            for match in matches {
                if let idrefRange = Range(match.range(at: 1), in: xml) {
                    spine.append(String(xml[idrefRange]))
                }
            }
        }

        return spine
    }

    /// Extract images referenced in an XHTML file
    private func extractImagesFromXHTML(at href: String, in archive: Archive) throws -> [String] {
        let fullPath = resolvePath(href)

        guard let xhtmlEntry = archive.first(where: { $0.path == fullPath }) else {
            return []
        }

        var xhtmlData = Data()
        do {
            _ = try archive.extract(xhtmlEntry) { data in
                xhtmlData.append(data)
            }
        } catch {
            return []
        }

        guard let xhtml = String(data: xhtmlData, encoding: .utf8) else {
            return []
        }

        var images: [String] = []

        // Find <img src="..."/> or <image xlink:href="..."/>
        let imgPattern = #"<img[^>]+src\s*=\s*["\']([^"\']+)["\']"#
        let svgImagePattern = #"<image[^>]+(?:xlink:)?href\s*=\s*["\']([^"\']+)["\']"#

        for pattern in [imgPattern, svgImagePattern] {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(xhtml.startIndex..., in: xhtml)
                let matches = regex.matches(in: xhtml, options: [], range: range)

                for match in matches {
                    if let srcRange = Range(match.range(at: 1), in: xhtml) {
                        let src = String(xhtml[srcRange]).removingPercentEncoding ?? String(xhtml[srcRange])
                        images.append(src)
                    }
                }
            }
        }

        return images
    }

    /// Extract an attribute value from an XML element
    private func extractAttribute(named name: String, from element: String, in xml: String) -> String? {
        let pattern = "<\(element)[^>]+\(name)\\s*=\\s*[\"']([^\"']+)[\"']"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }

        let range = NSRange(xml.startIndex..., in: xml)
        if let match = regex.firstMatch(in: xml, options: [], range: range),
           let valueRange = Range(match.range(at: 1), in: xml) {
            return String(xml[valueRange])
        }

        return nil
    }

    /// Extract attribute value from attribute string
    private func extractAttributeValue(named name: String, from attributes: String) -> String? {
        let pattern = "\(name)\\s*=\\s*[\"']([^\"']+)[\"']"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }

        let range = NSRange(attributes.startIndex..., in: attributes)
        if let match = regex.firstMatch(in: attributes, options: [], range: range),
           let valueRange = Range(match.range(at: 1), in: attributes) {
            return String(attributes[valueRange])
        }

        return nil
    }

    /// Resolve a relative path against the OPF base path
    private func resolvePath(_ href: String, relativeTo basePath: String? = nil) -> String {
        // Remove any leading ./
        var cleanHref = href
        while cleanHref.hasPrefix("./") {
            cleanHref = String(cleanHref.dropFirst(2))
        }

        // If we have a base path from the referencing file, use it
        if let base = basePath {
            let baseDir = URL(fileURLWithPath: opfBasePath + base).deletingLastPathComponent().path
            if !baseDir.isEmpty {
                let baseDirClean = baseDir.hasPrefix("/") ? String(baseDir.dropFirst()) : baseDir
                return baseDirClean.isEmpty ? cleanHref : baseDirClean + "/" + cleanHref
            }
        }

        // Otherwise use OPF base path
        return opfBasePath + cleanHref
    }

    /// Check if media type is an image
    private func isImageMediaType(_ mediaType: String) -> Bool {
        mediaType.hasPrefix("image/")
    }

    /// Check if media type is XHTML
    private func isXHTMLMediaType(_ mediaType: String) -> Bool {
        mediaType == "application/xhtml+xml" ||
        mediaType == "text/html" ||
        mediaType == "application/xml"
    }

    /// Create an ArchiveEntry for a path if it exists in the archive
    private func createEntry(for path: String, in archive: Archive, index: Int) -> ArchiveEntry? {
        guard let zipEntry = archive.first(where: { $0.path == path }) else {
            return nil
        }

        let size = UInt64(zipEntry.uncompressedSize)

        // Security: check entry size
        guard size <= ArchiveLimits.maxUncompressedEntrySize else {
            return nil
        }

        return ArchiveEntry(
            path: path,
            uncompressedSize: size,
            index: index
        )
    }

    // MARK: - Cleanup

    func cleanup() async {
        try? FileManager.default.removeItem(at: cacheDirectory)
    }

    deinit {
        try? FileManager.default.removeItem(at: cacheDirectory)
    }
}

// MARK: - Supporting Types

private struct ManifestItem {
    let id: String
    let href: String
    let mediaType: String
}
