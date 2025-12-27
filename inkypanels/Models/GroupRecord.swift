import Foundation
import SwiftData

/// SwiftData model for persisted manual file groups
@Model
final class GroupRecord {
    /// Unique identifier for the group
    @Attribute(.unique) var groupId: UUID

    /// Display name for the group
    var displayName: String

    /// File paths of members in this group
    var memberPaths: [String]

    /// Sort order for display (lower = first)
    var sortOrder: Int

    /// When this group was created
    var createdDate: Date

    init(
        groupId: UUID = UUID(),
        displayName: String,
        memberPaths: [String] = [],
        sortOrder: Int = 0,
        createdDate: Date = Date()
    ) {
        self.groupId = groupId
        self.displayName = displayName
        self.memberPaths = memberPaths
        self.sortOrder = sortOrder
        self.createdDate = createdDate
    }

    /// Number of members in this group
    var memberCount: Int {
        memberPaths.count
    }

    /// Add a file path to this group
    func addMember(_ filePath: String) {
        guard !memberPaths.contains(filePath) else { return }
        memberPaths.append(filePath)
    }

    /// Remove a file path from this group
    func removeMember(_ filePath: String) {
        memberPaths.removeAll { $0 == filePath }
    }

    /// Check if a file is in this group
    func containsMember(_ filePath: String) -> Bool {
        memberPaths.contains(filePath)
    }
}
