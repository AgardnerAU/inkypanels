import Foundation
import CryptoKit

/// Protocol for encryption operations (v0.4)
protocol EncryptionServiceProtocol: Sendable {
    /// Encrypt data with a symmetric key
    func encrypt(data: Data, withKey key: SymmetricKey) async throws -> Data

    /// Decrypt data with a symmetric key
    func decrypt(data: Data, withKey key: SymmetricKey) async throws -> Data

    /// Derive a symmetric key from a password and salt
    func deriveKey(from password: String, salt: Data) async throws -> SymmetricKey

    /// Generate a random salt for key derivation
    func generateSalt() -> Data
}
