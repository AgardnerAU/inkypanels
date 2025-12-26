import Foundation

/// Errors related to the secure vault
enum VaultError: Error, LocalizedError {
    case incorrectPassword
    case biometricFailed
    case biometricNotAvailable
    case encryptionFailed(underlying: Error)
    case decryptionFailed(underlying: Error)
    case manifestCorrupted
    case vaultNotSetUp
    case vaultLocked
    case fileAlreadyInVault
    case fileNotInVault

    var errorDescription: String? {
        switch self {
        case .incorrectPassword:
            return "Incorrect password"
        case .biometricFailed:
            return "Biometric authentication failed"
        case .biometricNotAvailable:
            return "Biometric authentication is not available"
        case .encryptionFailed(let error):
            return "Encryption failed: \(error.localizedDescription)"
        case .decryptionFailed(let error):
            return "Decryption failed: \(error.localizedDescription)"
        case .manifestCorrupted:
            return "Vault data is corrupted"
        case .vaultNotSetUp:
            return "Vault has not been set up"
        case .vaultLocked:
            return "Vault is locked"
        case .fileAlreadyInVault:
            return "File is already in the vault"
        case .fileNotInVault:
            return "File is not in the vault"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .incorrectPassword:
            return "Please try again with the correct password."
        case .biometricFailed:
            return "Try again or use your password instead."
        case .biometricNotAvailable:
            return "Please use your password to unlock the vault."
        case .encryptionFailed:
            return "Try again or contact support if the problem persists."
        case .decryptionFailed:
            return "The vault data may be corrupted. Try resetting the vault."
        case .manifestCorrupted:
            return "You may need to reset the vault. This will remove all encrypted files."
        case .vaultNotSetUp:
            return "Set up a vault password in Settings."
        case .vaultLocked:
            return "Unlock your vault first to add files."
        case .fileAlreadyInVault:
            return "The file is already protected in the vault."
        case .fileNotInVault:
            return "The file must be in the vault to perform this action."
        }
    }
}
