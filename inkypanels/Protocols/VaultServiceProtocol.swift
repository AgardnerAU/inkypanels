import Foundation

/// Protocol for vault operations (v0.4)
protocol VaultServiceProtocol: Sendable {
    /// Unlock the vault with a password
    func unlock(withPassword password: String) async throws

    /// Unlock the vault with biometric authentication
    func unlockWithBiometric() async throws

    /// Lock the vault
    func lock() async

    /// Whether the vault is currently unlocked
    var isUnlocked: Bool { get }

    /// Add a file to the vault (encrypts and moves)
    func addFile(_ file: ComicFile) async throws

    /// Remove a file from the vault (decrypts and moves back)
    func removeFile(_ item: VaultItem) async throws

    /// List all files in the vault
    func listFiles() async throws -> [VaultItem]

    /// Decrypt a file temporarily for reading
    func decryptFile(_ item: VaultItem) async throws -> URL

    /// Set up the vault with a new password
    func setupVault(password: String, enableBiometric: Bool) async throws

    /// Check if the vault has been set up
    var isVaultSetUp: Bool { get }
}
