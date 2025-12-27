import Foundation
import SwiftData
import os.log

/// Service for managing manual file groups using SwiftData
@MainActor
final class GroupingService {

    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "inkypanels", category: "GroupingService")
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Group CRUD Operations

    /// Create a new group
    func createGroup(name: String, memberPaths: [String] = []) async -> GroupRecord? {
        // Get next sort order
        let sortOrder = await getNextSortOrder()

        let record = GroupRecord(
            displayName: name,
            memberPaths: memberPaths,
            sortOrder: sortOrder
        )
        modelContext.insert(record)

        do {
            try modelContext.save()
            return record
        } catch {
            Self.logger.error("Failed to create group '\(name)': \(error.localizedDescription)")
            return nil
        }
    }

    /// Delete a group
    func deleteGroup(_ groupId: UUID) async {
        let descriptor = FetchDescriptor<GroupRecord>(
            predicate: #Predicate { $0.groupId == groupId }
        )

        do {
            let results = try modelContext.fetch(descriptor)
            for record in results {
                modelContext.delete(record)
            }
            try modelContext.save()
        } catch {
            Self.logger.error("Failed to delete group \(groupId): \(error.localizedDescription)")
        }
    }

    /// Update a group's name
    func renameGroup(_ groupId: UUID, to newName: String) async {
        let descriptor = FetchDescriptor<GroupRecord>(
            predicate: #Predicate { $0.groupId == groupId }
        )

        do {
            let results = try modelContext.fetch(descriptor)
            if let record = results.first {
                record.displayName = newName
                try modelContext.save()
            }
        } catch {
            Self.logger.error("Failed to rename group \(groupId) to '\(newName)': \(error.localizedDescription)")
        }
    }

    /// Fetch all groups sorted by sort order
    func fetchAllGroups() async -> [GroupRecord] {
        let descriptor = FetchDescriptor<GroupRecord>(
            sortBy: [SortDescriptor(\.sortOrder)]
        )

        do {
            return try modelContext.fetch(descriptor)
        } catch {
            Self.logger.error("Failed to fetch groups: \(error.localizedDescription)")
            return []
        }
    }

    /// Fetch a specific group by ID
    func fetchGroup(_ groupId: UUID) async -> GroupRecord? {
        let descriptor = FetchDescriptor<GroupRecord>(
            predicate: #Predicate { $0.groupId == groupId }
        )

        do {
            return try modelContext.fetch(descriptor).first
        } catch {
            Self.logger.error("Failed to fetch group \(groupId): \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Group Membership Operations

    /// Add files to a group
    func addToGroup(_ groupId: UUID, filePaths: [String]) async {
        guard let record = await fetchGroup(groupId) else { return }

        for path in filePaths {
            record.addMember(path)
        }

        do {
            try modelContext.save()
        } catch {
            Self.logger.error("Failed to add files to group \(groupId): \(error.localizedDescription)")
        }
    }

    /// Remove files from a group
    func removeFromGroup(_ groupId: UUID, filePaths: [String]) async {
        guard let record = await fetchGroup(groupId) else { return }

        for path in filePaths {
            record.removeMember(path)
        }

        do {
            try modelContext.save()
        } catch {
            Self.logger.error("Failed to remove files from group \(groupId): \(error.localizedDescription)")
        }
    }

    /// Find which group contains a file (if any)
    func findGroupContaining(filePath: String) async -> GroupRecord? {
        let allGroups = await fetchAllGroups()
        return allGroups.first { $0.containsMember(filePath) }
    }

    /// Get set of all file paths that are in manual groups
    func allGroupedFilePaths() async -> Set<String> {
        let allGroups = await fetchAllGroups()
        var paths = Set<String>()
        for group in allGroups {
            paths.formUnion(group.memberPaths)
        }
        return paths
    }

    // MARK: - Group Ordering

    /// Update sort orders for groups
    func updateSortOrders(_ orderedGroupIds: [UUID]) async {
        let allGroups = await fetchAllGroups()
        let groupMap = Dictionary(uniqueKeysWithValues: allGroups.map { ($0.groupId, $0) })

        for (index, groupId) in orderedGroupIds.enumerated() {
            if let record = groupMap[groupId] {
                record.sortOrder = index
            }
        }

        do {
            try modelContext.save()
        } catch {
            Self.logger.error("Failed to update sort orders: \(error.localizedDescription)")
        }
    }

    // MARK: - Helper Methods

    private func getNextSortOrder() async -> Int {
        let allGroups = await fetchAllGroups()
        let maxOrder = allGroups.map(\.sortOrder).max() ?? -1
        return maxOrder + 1
    }

    // MARK: - Display Group Conversion

    /// Convert GroupRecords to DisplayGroups with file data
    func toDisplayGroups(
        _ records: [GroupRecord],
        files: [ComicFile]
    ) -> [DisplayGroup] {
        let fileMap = Dictionary(
            uniqueKeysWithValues: files.map { ($0.url.path, $0) }
        )

        return records.compactMap { record in
            let memberFiles = record.memberPaths.compactMap { fileMap[$0] }
            guard !memberFiles.isEmpty else { return nil }

            return DisplayGroup(
                id: "manual-\(record.groupId.uuidString)",
                name: record.displayName,
                files: memberFiles,
                isAutomatic: false,
                pattern: nil
            )
        }
    }
}
