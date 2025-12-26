import CryptoKit
import Foundation

/// Vault service for managing encrypted file storage
actor VaultService: @preconcurrency VaultServiceProtocol {

    // MARK: - Shared Instance

    static let shared = VaultService()

    // MARK: - Dependencies

    private let encryptionService: EncryptionService
    private let keychainService: KeychainService

    // MARK: - State

    private var vaultKey: SymmetricKey?
    private var cachedManifest: [VaultItem] = []

    // MARK: - Computed Properties

    nonisolated var isUnlocked: Bool {
        // We can't access actor state from nonisolated, so we check keychain
        keychainService.exists(for: KeychainService.Keys.salt)
    }

    nonisolated var isVaultSetUp: Bool {
        keychainService.exists(for: KeychainService.Keys.salt)
    }

    // MARK: - Directories

    nonisolated var vaultDirectory: URL {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsURL.appendingPathComponent(Constants.Paths.vaultFolder, isDirectory: true)
    }

    nonisolated var vaultFilesDirectory: URL {
        vaultDirectory.appendingPathComponent(Constants.Paths.vaultFilesFolder, isDirectory: true)
    }

    nonisolated var manifestURL: URL {
        vaultDirectory.appendingPathComponent(Constants.Paths.vaultManifest)
    }

    // MARK: - Init

    init(encryptionService: EncryptionService = EncryptionService(),
         keychainService: KeychainService = KeychainService()) {
        self.encryptionService = encryptionService
        self.keychainService = keychainService
    }

    // MARK: - Setup

    func setupVault(password: String, enableBiometric: Bool) async throws {
        // Generate salt
        let salt = encryptionService.generateSalt()

        // Derive key from password
        let key = try await encryptionService.deriveKey(from: password, salt: salt)

        // Create vault directories
        try createVaultDirectories()

        // Create empty manifest
        let emptyManifest: [VaultItem] = []
        try await saveManifest(emptyManifest, withKey: key)

        // Save salt to keychain (not biometric protected)
        try await keychainService.save(salt, for: KeychainService.Keys.salt, requireBiometric: false)

        // If biometric enabled, save derived key to keychain with biometric protection
        if enableBiometric {
            let keyData = key.withUnsafeBytes { Data($0) }
            try await keychainService.save(keyData, for: KeychainService.Keys.derivedKey, requireBiometric: true)
            try await keychainService.save(Data([1]), for: KeychainService.Keys.biometricEnabled, requireBiometric: false)
        }

        // Store key in memory
        vaultKey = key
        cachedManifest = emptyManifest
    }

    // MARK: - Unlock

    func unlock(withPassword password: String) async throws {
        // Get salt from keychain
        guard let salt = try await keychainService.retrieve(for: KeychainService.Keys.salt, prompt: "") else {
            throw VaultError.vaultNotSetUp
        }

        // Derive key from password
        let key = try await encryptionService.deriveKey(from: password, salt: salt)

        // Try to decrypt manifest to verify password
        do {
            let manifest = try await loadManifest(withKey: key)
            vaultKey = key
            cachedManifest = manifest
        } catch {
            throw VaultError.incorrectPassword
        }
    }

    func unlockWithBiometric() async throws {
        // Check if biometric is enabled
        guard let enabledData = try await keychainService.retrieve(for: KeychainService.Keys.biometricEnabled, prompt: ""),
              enabledData.first == 1 else {
            throw VaultError.biometricNotAvailable
        }

        // Authenticate with biometric
        try await keychainService.authenticateWithBiometric(reason: "Unlock your vault")

        // Retrieve derived key (biometric protected)
        guard let keyData = try await keychainService.retrieve(
            for: KeychainService.Keys.derivedKey,
            prompt: "Unlock your vault"
        ) else {
            throw VaultError.biometricFailed
        }

        let key = SymmetricKey(data: keyData)

        // Load manifest
        let manifest = try await loadManifest(withKey: key)
        vaultKey = key
        cachedManifest = manifest
    }

    // MARK: - Lock

    func lock() {
        vaultKey = nil
        cachedManifest = []
        cleanupTemporaryFiles()
    }

    // MARK: - File Operations

    func addFile(_ file: ComicFile) async throws {
        guard let key = vaultKey else {
            throw VaultError.vaultNotSetUp
        }

        // Check if file already in vault
        if cachedManifest.contains(where: { $0.originalName == file.name }) {
            throw VaultError.fileAlreadyInVault
        }

        // Read original file
        let fileData = try Data(contentsOf: file.url)

        // Encrypt file
        let encryptedData = try await encryptionService.encrypt(data: fileData, withKey: key)

        // Generate random filename
        let encryptedFileName = UUID().uuidString + ".enc"
        let encryptedURL = vaultFilesDirectory.appendingPathComponent(encryptedFileName)

        // Write encrypted file
        try encryptedData.write(to: encryptedURL, options: .atomic)

        // Create vault item
        let vaultItem = VaultItem(
            originalName: file.name + "." + file.url.pathExtension,
            encryptedFileName: encryptedFileName,
            fileSize: file.fileSize,
            fileType: file.fileType
        )

        // Update manifest
        cachedManifest.append(vaultItem)
        try await saveManifest(cachedManifest, withKey: key)

        // Securely delete original file
        try secureDelete(url: file.url)
    }

    func removeFile(_ item: VaultItem) async throws {
        guard let key = vaultKey else {
            throw VaultError.vaultNotSetUp
        }

        guard cachedManifest.contains(where: { $0.id == item.id }) else {
            throw VaultError.fileNotInVault
        }

        // Decrypt file
        let encryptedURL = vaultFilesDirectory.appendingPathComponent(item.encryptedFileName)
        let encryptedData = try Data(contentsOf: encryptedURL)
        let decryptedData = try await encryptionService.decrypt(data: encryptedData, withKey: key)

        // Determine destination
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let comicsURL = documentsURL.appendingPathComponent(Constants.Paths.comicsFolder, isDirectory: true)

        // Create comics directory if needed
        try? FileManager.default.createDirectory(at: comicsURL, withIntermediateDirectories: true)

        // Write decrypted file
        let destinationURL = comicsURL.appendingPathComponent(item.originalName)
        try decryptedData.write(to: destinationURL, options: .atomic)

        // Remove from manifest
        cachedManifest.removeAll { $0.id == item.id }
        try await saveManifest(cachedManifest, withKey: key)

        // Delete encrypted file
        try FileManager.default.removeItem(at: encryptedURL)
    }

    func listFiles() async throws -> [VaultItem] {
        guard vaultKey != nil else {
            throw VaultError.vaultNotSetUp
        }

        return cachedManifest
    }

    func decryptFile(_ item: VaultItem) async throws -> URL {
        guard let key = vaultKey else {
            throw VaultError.vaultNotSetUp
        }

        // Read encrypted file
        let encryptedURL = vaultFilesDirectory.appendingPathComponent(item.encryptedFileName)
        let encryptedData = try Data(contentsOf: encryptedURL)

        // Decrypt
        let decryptedData = try await encryptionService.decrypt(data: encryptedData, withKey: key)

        // Write to temporary location
        let tempURL = temporaryDirectory.appendingPathComponent(UUID().uuidString + "_" + item.originalName)
        try decryptedData.write(to: tempURL, options: .atomic)

        return tempURL
    }

    // MARK: - Biometric Management

    func isBiometricEnabled() async -> Bool {
        guard let data = try? await keychainService.retrieve(for: KeychainService.Keys.biometricEnabled, prompt: "") else {
            return false
        }
        return data.first == 1
    }

    func setBiometricEnabled(_ enabled: Bool, password: String) async throws {
        // Verify password first
        guard let salt = try await keychainService.retrieve(for: KeychainService.Keys.salt, prompt: "") else {
            throw VaultError.vaultNotSetUp
        }

        let key = try await encryptionService.deriveKey(from: password, salt: salt)

        // Verify key by decrypting manifest
        _ = try await loadManifest(withKey: key)

        if enabled {
            // Save key with biometric protection
            let keyData = key.withUnsafeBytes { Data($0) }
            try await keychainService.save(keyData, for: KeychainService.Keys.derivedKey, requireBiometric: true)
            try await keychainService.save(Data([1]), for: KeychainService.Keys.biometricEnabled, requireBiometric: false)
        } else {
            // Remove biometric key
            try await keychainService.delete(for: KeychainService.Keys.derivedKey)
            try await keychainService.delete(for: KeychainService.Keys.biometricEnabled)
        }
    }

    func changePassword(currentPassword: String, newPassword: String) async throws {
        // Verify current password
        guard let salt = try await keychainService.retrieve(for: KeychainService.Keys.salt, prompt: "") else {
            throw VaultError.vaultNotSetUp
        }

        let currentKey = try await encryptionService.deriveKey(from: currentPassword, salt: salt)

        // Verify by decrypting manifest
        let manifest = try await loadManifest(withKey: currentKey)

        // Generate new salt and derive new key
        let newSalt = encryptionService.generateSalt()
        let newKey = try await encryptionService.deriveKey(from: newPassword, salt: newSalt)

        // Re-encrypt all files with new key
        for item in manifest {
            let encryptedURL = vaultFilesDirectory.appendingPathComponent(item.encryptedFileName)
            let encryptedData = try Data(contentsOf: encryptedURL)
            let decryptedData = try await encryptionService.decrypt(data: encryptedData, withKey: currentKey)
            let reEncryptedData = try await encryptionService.encrypt(data: decryptedData, withKey: newKey)
            try reEncryptedData.write(to: encryptedURL, options: .atomic)
        }

        // Save new manifest
        try await saveManifest(manifest, withKey: newKey)

        // Update salt in keychain
        try await keychainService.save(newSalt, for: KeychainService.Keys.salt, requireBiometric: false)

        // Update biometric key if enabled
        if await isBiometricEnabled() {
            let keyData = newKey.withUnsafeBytes { Data($0) }
            try await keychainService.save(keyData, for: KeychainService.Keys.derivedKey, requireBiometric: true)
        }

        // Update in-memory key
        vaultKey = newKey
    }

    func deleteVault(password: String) async throws {
        // Verify password
        guard let salt = try await keychainService.retrieve(for: KeychainService.Keys.salt, prompt: "") else {
            throw VaultError.vaultNotSetUp
        }

        let key = try await encryptionService.deriveKey(from: password, salt: salt)
        _ = try await loadManifest(withKey: key)

        // Delete all vault files
        try? FileManager.default.removeItem(at: vaultDirectory)

        // Delete keychain items
        try await keychainService.delete(for: KeychainService.Keys.salt)
        try await keychainService.delete(for: KeychainService.Keys.derivedKey)
        try await keychainService.delete(for: KeychainService.Keys.biometricEnabled)

        // Clear state
        vaultKey = nil
        cachedManifest = []
    }

    // MARK: - Private Helpers

    private func createVaultDirectories() throws {
        try FileManager.default.createDirectory(at: vaultDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: vaultFilesDirectory, withIntermediateDirectories: true)

        // Set hidden attribute on vault folder (for macOS visibility)
        var resourceValues = URLResourceValues()
        resourceValues.isHidden = true
        var mutableURL = vaultDirectory
        try mutableURL.setResourceValues(resourceValues)
    }

    private func saveManifest(_ manifest: [VaultItem], withKey key: SymmetricKey) async throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let jsonData = try encoder.encode(manifest)

        let encryptedData = try await encryptionService.encrypt(data: jsonData, withKey: key)
        try encryptedData.write(to: manifestURL, options: .atomic)
    }

    private func loadManifest(withKey key: SymmetricKey) async throws -> [VaultItem] {
        guard FileManager.default.fileExists(atPath: manifestURL.path) else {
            return []
        }

        let encryptedData = try Data(contentsOf: manifestURL)
        let jsonData = try await encryptionService.decrypt(data: encryptedData, withKey: key)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([VaultItem].self, from: jsonData)
    }

    private nonisolated var temporaryDirectory: URL {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("inkypanels-vault", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }

    private func cleanupTemporaryFiles() {
        try? FileManager.default.removeItem(at: temporaryDirectory)
    }

    private func secureDelete(url: URL) throws {
        // Overwrite with random data before deletion
        let fileSize = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int ?? 0

        if fileSize > 0 {
            let randomData = Data((0..<fileSize).map { _ in UInt8.random(in: 0...255) })
            try randomData.write(to: url, options: .atomic)
        }

        try FileManager.default.removeItem(at: url)
    }

    // MARK: - Unlocked State Check

    func checkUnlocked() -> Bool {
        return vaultKey != nil
    }
}
