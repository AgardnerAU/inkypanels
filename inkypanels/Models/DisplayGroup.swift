import Foundation

/// Represents a group of files for display in the library view
struct DisplayGroup: Identifiable, Hashable {
    /// Unique identifier for the group (pattern for auto-groups, UUID string for manual)
    let id: String

    /// Display name for the group
    let name: String

    /// Files contained in this group, sorted by volume/issue number
    let files: [ComicFile]

    /// Whether this group was auto-detected or manually created
    let isAutomatic: Bool

    /// The common pattern that matched these files (for auto-groups)
    let pattern: String?

    /// Number of files in the group
    var fileCount: Int { files.count }

    /// First file's URL for thumbnail generation
    var coverURL: URL? { files.first?.url }

    /// Total size of all files in the group
    var totalSize: Int64 {
        files.reduce(0) { $0 + $1.fileSize }
    }

    init(
        id: String,
        name: String,
        files: [ComicFile],
        isAutomatic: Bool = true,
        pattern: String? = nil
    ) {
        self.id = id
        self.name = name
        self.files = files
        self.isAutomatic = isAutomatic
        self.pattern = pattern
    }

    // MARK: - Hashable

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: DisplayGroup, rhs: DisplayGroup) -> Bool {
        lhs.id == rhs.id
    }
}

/// Result of extracting a series pattern from a filename
struct SeriesPattern: Hashable {
    /// The base series name (e.g., "Batman", "One Piece")
    let baseName: String

    /// The volume/issue indicator if found (e.g., "Vol.", "#", "Chapter")
    let volumeIndicator: String?

    /// The volume/issue number if extracted
    let volumeNumber: Int?

    /// The original filename this was extracted from
    let originalName: String

    /// A normalized key for grouping (lowercase, trimmed base name)
    var groupKey: String {
        baseName.lowercased().trimmingCharacters(in: .whitespaces)
    }
}
