import Foundation

/// Represents a single page within a comic
struct ComicPage: Identifiable, Sendable {
    let id: UUID
    let index: Int
    let fileName: String
    let imageData: Data?
    let imageURL: URL?

    /// Size of the image data in bytes
    var dataSize: Int {
        imageData?.count ?? 0
    }

    init(
        id: UUID = UUID(),
        index: Int,
        fileName: String,
        imageData: Data? = nil,
        imageURL: URL? = nil
    ) {
        self.id = id
        self.index = index
        self.fileName = fileName
        self.imageData = imageData
        self.imageURL = imageURL
    }
}

/// Page metadata without the actual image data (for listings)
struct ComicPageMetadata: Identifiable, Sendable {
    let id: UUID
    let index: Int
    let fileName: String
    let fileSize: Int64

    init(
        id: UUID = UUID(),
        index: Int,
        fileName: String,
        fileSize: Int64
    ) {
        self.id = id
        self.index = index
        self.fileName = fileName
        self.fileSize = fileSize
    }
}
