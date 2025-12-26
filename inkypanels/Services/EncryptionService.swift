import CryptoKit
import Foundation

/// AES-256-GCM encryption service with PBKDF2 key derivation
actor EncryptionService: EncryptionServiceProtocol {

    // MARK: - Encryption

    func encrypt(data: Data, withKey key: SymmetricKey) async throws -> Data {
        do {
            // Generate random nonce (12 bytes for GCM)
            let nonce = AES.GCM.Nonce()

            // Encrypt with AES-256-GCM
            let sealedBox = try AES.GCM.seal(data, using: key, nonce: nonce)

            // Combine: nonce (12 bytes) + ciphertext + tag (16 bytes)
            guard let combined = sealedBox.combined else {
                throw VaultError.encryptionFailed(underlying: NSError(
                    domain: "EncryptionService",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to combine encrypted data"]
                ))
            }

            return combined
        } catch let error as VaultError {
            throw error
        } catch {
            throw VaultError.encryptionFailed(underlying: error)
        }
    }

    // MARK: - Decryption

    func decrypt(data: Data, withKey key: SymmetricKey) async throws -> Data {
        do {
            // Create sealed box from combined data
            let sealedBox = try AES.GCM.SealedBox(combined: data)

            // Decrypt and verify authentication tag
            let decryptedData = try AES.GCM.open(sealedBox, using: key)

            return decryptedData
        } catch {
            throw VaultError.decryptionFailed(underlying: error)
        }
    }

    // MARK: - Key Derivation

    func deriveKey(from password: String, salt: Data) async throws -> SymmetricKey {
        guard let passwordData = password.data(using: .utf8) else {
            throw VaultError.encryptionFailed(underlying: NSError(
                domain: "EncryptionService",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "Invalid password encoding"]
            ))
        }

        // PBKDF2 with SHA256, 600k iterations, 32-byte output (256 bits)
        let derivedKey = try pbkdf2(
            password: passwordData,
            salt: salt,
            iterations: Constants.Security.pbkdf2Iterations,
            keyLength: 32
        )

        return SymmetricKey(data: derivedKey)
    }

    // MARK: - Salt Generation

    nonisolated func generateSalt() -> Data {
        var bytes = [UInt8](repeating: 0, count: Constants.Security.saltLength)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)

        if status != errSecSuccess {
            // Fallback to less secure random if SecRandomCopyBytes fails
            bytes = (0..<Constants.Security.saltLength).map { _ in UInt8.random(in: 0...255) }
        }

        return Data(bytes)
    }

    // MARK: - Private Helpers

    /// PBKDF2 key derivation using CommonCrypto via CryptoKit
    private func pbkdf2(password: Data, salt: Data, iterations: Int, keyLength: Int) throws -> Data {
        // Use CryptoKit's HKDF as a workaround since PBKDF2 isn't directly exposed
        // Actually, we need to use CommonCrypto for PBKDF2

        var derivedKeyData = Data(count: keyLength)
        let derivationStatus = derivedKeyData.withUnsafeMutableBytes { derivedKeyBytes in
            salt.withUnsafeBytes { saltBytes in
                password.withUnsafeBytes { passwordBytes in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordBytes.baseAddress?.assumingMemoryBound(to: Int8.self),
                        password.count,
                        saltBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        UInt32(iterations),
                        derivedKeyBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        keyLength
                    )
                }
            }
        }

        guard derivationStatus == kCCSuccess else {
            throw VaultError.encryptionFailed(underlying: NSError(
                domain: "EncryptionService",
                code: Int(derivationStatus),
                userInfo: [NSLocalizedDescriptionKey: "PBKDF2 key derivation failed"]
            ))
        }

        return derivedKeyData
    }
}

// MARK: - CommonCrypto Import

import CommonCrypto
