import Foundation

/// Protocol for Keychain operations (v0.4)
protocol KeychainServiceProtocol: Sendable {
    /// Save data to the Keychain
    func save(_ data: Data, for key: String, requireBiometric: Bool) async throws

    /// Retrieve data from the Keychain
    func retrieve(for key: String, prompt: String) async throws -> Data?

    /// Delete data from the Keychain
    func delete(for key: String) async throws

    /// Check if a key exists in the Keychain
    func exists(for key: String) -> Bool
}
