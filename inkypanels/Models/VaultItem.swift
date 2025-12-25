import Foundation

/// Represents an encrypted file stored in the vault
struct VaultItem: Identifiable, Codable, Sendable {
    let id: UUID
    let originalName: String
    let encryptedFileName: String
    let addedDate: Date
    let fileSize: Int64
    let fileType: ComicFileType

    init(
        id: UUID = UUID(),
        originalName: String,
        encryptedFileName: String,
        addedDate: Date = Date(),
        fileSize: Int64,
        fileType: ComicFileType
    ) {
        self.id = id
        self.originalName = originalName
        self.encryptedFileName = encryptedFileName
        self.addedDate = addedDate
        self.fileSize = fileSize
        self.fileType = fileType
    }
}

// MARK: - ComicFileType Codable Conformance

extension ComicFileType: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = ComicFileType(from: rawValue)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }
}
