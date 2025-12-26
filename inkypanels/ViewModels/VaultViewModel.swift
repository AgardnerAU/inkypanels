import Foundation
import LocalAuthentication

/// Vault state enum
enum VaultState: Equatable {
    case notSetUp
    case locked
    case unlocked
}

/// ViewModel for vault operations
@MainActor
@Observable
final class VaultViewModel {

    // MARK: - State

    var vaultState: VaultState = .locked
    var vaultItems: [VaultItem] = []
    var isLoading: Bool = false
    var error: VaultError?
    var showError: Bool = false

    // Biometric state
    var isBiometricAvailable: Bool = false
    var isBiometricEnabled: Bool = false
    var biometryType: LABiometryType = .none

    // Setup fields
    var setupPassword: String = ""
    var confirmPassword: String = ""
    var enableBiometricOnSetup: Bool = false

    // Unlock fields
    var unlockPassword: String = ""

    // Settings fields
    var showSettings: Bool = false
    var currentPasswordForChange: String = ""
    var newPassword: String = ""
    var confirmNewPassword: String = ""

    // File operations
    var selectedFile: VaultItem?
    var decryptedFileURL: URL?

    // MARK: - Dependencies

    private var vaultService: VaultService?
    private var keychainService: KeychainService?

    // MARK: - Init

    init() {
        let keychain = KeychainService()
        self.keychainService = keychain
        self.vaultService = VaultService(keychainService: keychain)
    }

    // MARK: - Configuration

    func configure() async {
        await checkVaultStatus()
        await checkBiometricAvailability()
    }

    // MARK: - Status Check

    func checkVaultStatus() async {
        guard let vaultService else { return }

        let isSetUp = vaultService.isVaultSetUp
        let isUnlocked = await vaultService.checkUnlocked()

        if !isSetUp {
            vaultState = .notSetUp
        } else if isUnlocked {
            vaultState = .unlocked
            await loadVaultItems()
        } else {
            vaultState = .locked
        }

        isBiometricEnabled = await vaultService.isBiometricEnabled()
    }

    private func checkBiometricAvailability() async {
        guard let keychainService else { return }

        isBiometricAvailable = keychainService.isBiometricAvailable()
        biometryType = keychainService.biometryType()
    }

    // MARK: - Setup

    var canSetupVault: Bool {
        !setupPassword.isEmpty &&
        setupPassword == confirmPassword &&
        setupPassword.count >= 4
    }

    func setupVault() async {
        guard canSetupVault, let vaultService else { return }

        isLoading = true
        error = nil

        do {
            try await vaultService.setupVault(
                password: setupPassword,
                enableBiometric: enableBiometricOnSetup && isBiometricAvailable
            )

            vaultState = .unlocked
            isBiometricEnabled = enableBiometricOnSetup && isBiometricAvailable
            setupPassword = ""
            confirmPassword = ""
            enableBiometricOnSetup = false

            await loadVaultItems()
        } catch let vaultError as VaultError {
            error = vaultError
            showError = true
        } catch {
            self.error = .encryptionFailed(underlying: error)
            showError = true
        }

        isLoading = false
    }

    // MARK: - Unlock

    var canUnlock: Bool {
        !unlockPassword.isEmpty
    }

    func unlockWithPassword() async {
        guard canUnlock, let vaultService else { return }

        isLoading = true
        error = nil

        do {
            try await vaultService.unlock(withPassword: unlockPassword)
            vaultState = .unlocked
            unlockPassword = ""
            await loadVaultItems()
        } catch let vaultError as VaultError {
            error = vaultError
            showError = true
        } catch {
            self.error = .incorrectPassword
            showError = true
        }

        isLoading = false
    }

    func unlockWithBiometric() async {
        guard isBiometricEnabled, let vaultService else { return }

        isLoading = true
        error = nil

        do {
            try await vaultService.unlockWithBiometric()
            vaultState = .unlocked
            await loadVaultItems()
        } catch let vaultError as VaultError {
            error = vaultError
            showError = true
        } catch {
            self.error = .biometricFailed
            showError = true
        }

        isLoading = false
    }

    // MARK: - Lock

    func lock() {
        Task {
            await vaultService?.lock()
        }
        vaultState = .locked
        vaultItems = []
        decryptedFileURL = nil
    }

    // MARK: - File Operations

    private func loadVaultItems() async {
        guard let vaultService else { return }

        do {
            vaultItems = try await vaultService.listFiles()
        } catch {
            vaultItems = []
        }
    }

    func addFile(_ file: ComicFile) async {
        guard let vaultService else { return }

        isLoading = true
        error = nil

        do {
            try await vaultService.addFile(file)
            await loadVaultItems()
        } catch let vaultError as VaultError {
            error = vaultError
            showError = true
        } catch {
            self.error = .encryptionFailed(underlying: error)
            showError = true
        }

        isLoading = false
    }

    func removeFile(_ item: VaultItem) async {
        guard let vaultService else { return }

        isLoading = true
        error = nil

        do {
            try await vaultService.removeFile(item)
            await loadVaultItems()
        } catch let vaultError as VaultError {
            error = vaultError
            showError = true
        } catch {
            self.error = .decryptionFailed(underlying: error)
            showError = true
        }

        isLoading = false
    }

    func openFile(_ item: VaultItem) async -> URL? {
        guard let vaultService else { return nil }

        isLoading = true
        error = nil

        do {
            let url = try await vaultService.decryptFile(item)
            decryptedFileURL = url
            isLoading = false
            return url
        } catch let vaultError as VaultError {
            error = vaultError
            showError = true
        } catch {
            self.error = .decryptionFailed(underlying: error)
            showError = true
        }

        isLoading = false
        return nil
    }

    // MARK: - Settings

    func toggleBiometric(enabled: Bool, password: String) async {
        guard let vaultService else { return }

        isLoading = true
        error = nil

        do {
            try await vaultService.setBiometricEnabled(enabled, password: password)
            isBiometricEnabled = enabled
        } catch let vaultError as VaultError {
            error = vaultError
            showError = true
        } catch {
            self.error = .incorrectPassword
            showError = true
        }

        isLoading = false
    }

    var canChangePassword: Bool {
        !currentPasswordForChange.isEmpty &&
        !newPassword.isEmpty &&
        newPassword == confirmNewPassword &&
        newPassword.count >= 4
    }

    func changePassword() async {
        guard canChangePassword, let vaultService else { return }

        isLoading = true
        error = nil

        do {
            try await vaultService.changePassword(
                currentPassword: currentPasswordForChange,
                newPassword: newPassword
            )

            currentPasswordForChange = ""
            newPassword = ""
            confirmNewPassword = ""
        } catch let vaultError as VaultError {
            error = vaultError
            showError = true
        } catch {
            self.error = .incorrectPassword
            showError = true
        }

        isLoading = false
    }

    func deleteVault(password: String) async {
        guard let vaultService else { return }

        isLoading = true
        error = nil

        do {
            try await vaultService.deleteVault(password: password)
            vaultState = .notSetUp
            vaultItems = []
            isBiometricEnabled = false
        } catch let vaultError as VaultError {
            error = vaultError
            showError = true
        } catch {
            self.error = .incorrectPassword
            showError = true
        }

        isLoading = false
    }

    // MARK: - Helpers

    var biometryName: String {
        switch biometryType {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        case .opticID:
            return "Optic ID"
        default:
            return "Biometric"
        }
    }
}
