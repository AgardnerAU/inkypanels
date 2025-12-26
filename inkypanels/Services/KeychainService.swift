import Foundation
import LocalAuthentication
import Security

/// Keychain service for secure storage with optional biometric protection
actor KeychainService: KeychainServiceProtocol {

    // MARK: - Constants

    private nonisolated let service = Constants.Security.keychainService

    // Keychain keys for vault
    enum Keys {
        static let salt = "vault.salt"
        static let derivedKey = "vault.key"
        static let biometricEnabled = "vault.biometric"
    }

    // MARK: - Save

    func save(_ data: Data, for key: String, requireBiometric: Bool) async throws {
        // Delete existing item first
        try? await delete(for: key)

        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        // Add biometric protection if requested
        if requireBiometric {
            var error: Unmanaged<CFError>?
            guard let accessControl = SecAccessControlCreateWithFlags(
                nil,
                kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                .biometryCurrentSet,
                &error
            ) else {
                throw VaultError.encryptionFailed(underlying: error?.takeRetainedValue() ?? NSError(
                    domain: "KeychainService",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to create access control"]
                ))
            }

            query[kSecAttrAccessControl as String] = accessControl
            query.removeValue(forKey: kSecAttrAccessible as String)
        }

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw VaultError.encryptionFailed(underlying: NSError(
                domain: "KeychainService",
                code: Int(status),
                userInfo: [NSLocalizedDescriptionKey: "Keychain save failed with status: \(status)"]
            ))
        }
    }

    // MARK: - Retrieve

    func retrieve(for key: String, prompt: String) async throws -> Data? {
        let context = LAContext()
        // Set localizedReason on LAContext instead of deprecated kSecUseOperationPrompt
        if !prompt.isEmpty {
            context.localizedReason = prompt
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecUseAuthenticationContext as String: context
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            guard let data = result as? Data else {
                throw VaultError.encryptionFailed(underlying: NSError(
                    domain: "KeychainService",
                    code: -2,
                    userInfo: [NSLocalizedDescriptionKey: "Invalid keychain data format"]
                ))
            }
            return data

        case errSecItemNotFound:
            return nil

        case errSecUserCanceled, errSecAuthFailed:
            throw VaultError.biometricFailed

        default:
            throw VaultError.encryptionFailed(underlying: NSError(
                domain: "KeychainService",
                code: Int(status),
                userInfo: [NSLocalizedDescriptionKey: "Keychain retrieve failed with status: \(status)"]
            ))
        }
    }

    // MARK: - Delete

    func delete(for key: String) async throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw VaultError.encryptionFailed(underlying: NSError(
                domain: "KeychainService",
                code: Int(status),
                userInfo: [NSLocalizedDescriptionKey: "Keychain delete failed with status: \(status)"]
            ))
        }
    }

    // MARK: - Exists

    nonisolated func exists(for key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: false
        ]

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    // MARK: - Biometric Support

    /// Check if biometric authentication is available on this device
    nonisolated func isBiometricAvailable() -> Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    /// Get the type of biometric available (Face ID or Touch ID)
    nonisolated func biometryType() -> LABiometryType {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return context.biometryType
    }

    /// Authenticate using biometrics
    func authenticateWithBiometric(reason: String) async throws {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            throw VaultError.biometricNotAvailable
        }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )

            guard success else {
                throw VaultError.biometricFailed
            }
        } catch let laError as LAError {
            switch laError.code {
            case .userCancel, .userFallback:
                throw VaultError.biometricFailed
            case .biometryNotAvailable, .biometryNotEnrolled:
                throw VaultError.biometricNotAvailable
            default:
                throw VaultError.biometricFailed
            }
        } catch {
            throw VaultError.biometricFailed
        }
    }
}
