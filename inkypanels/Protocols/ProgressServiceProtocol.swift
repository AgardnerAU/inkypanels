import Foundation

/// Protocol for reading progress persistence
protocol ProgressServiceProtocol: Sendable {
    /// Save reading progress for a comic
    func saveProgress(_ progress: ReadingProgress) async throws

    /// Load reading progress for a comic
    func loadProgress(for comicId: UUID) async throws -> ReadingProgress?

    /// Mark a comic as completed
    func markAsCompleted(comicId: UUID) async throws

    /// Delete reading progress for a comic
    func deleteProgress(for comicId: UUID) async throws

    /// Load all reading progress records
    func loadAllProgress() async throws -> [ReadingProgress]
}
