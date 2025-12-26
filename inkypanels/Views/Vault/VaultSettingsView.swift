import SwiftUI

/// Settings view for vault configuration
struct VaultSettingsView: View {
    @Bindable var viewModel: VaultViewModel
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Constants.UserDefaultsKey.hideVaultFromSidebar) private var hideVaultFromSidebar = false

    @State private var showBiometricToggle = false
    @State private var biometricPassword = ""
    @State private var showChangePassword = false
    @State private var showDeleteVault = false
    @State private var deletePassword = ""

    var body: some View {
        NavigationStack {
            Form {
                // Biometric section
                if viewModel.isBiometricAvailable {
                    Section {
                        Toggle(isOn: Binding(
                            get: { viewModel.isBiometricEnabled },
                            set: { newValue in
                                showBiometricToggle = true
                            }
                        )) {
                            Label {
                                Text("Use \(viewModel.biometryName)")
                            } icon: {
                                Image(systemName: biometricIcon)
                            }
                        }
                    } header: {
                        Text("Quick Unlock")
                    } footer: {
                        Text("When enabled, you can unlock your vault using \(viewModel.biometryName) instead of entering your password.")
                    }
                }

                // Password section
                Section {
                    Button {
                        showChangePassword = true
                    } label: {
                        Label("Change Password", systemImage: "key")
                    }
                } header: {
                    Text("Security")
                }

                // Privacy section
                Section {
                    Toggle("Hide Vault from Sidebar", isOn: $hideVaultFromSidebar)
                } header: {
                    Text("Privacy")
                } footer: {
                    Text("When enabled, the Vault will be hidden from the sidebar. To access it, go to Settings and tap the app name 3 times.")
                }

                // Danger zone
                Section {
                    Button(role: .destructive) {
                        showDeleteVault = true
                    } label: {
                        Label("Delete Vault", systemImage: "trash")
                    }
                } header: {
                    Text("Danger Zone")
                } footer: {
                    Text("Deleting your vault will permanently remove all encrypted files. This action cannot be undone.")
                }
            }
            .navigationTitle("Vault Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            // Biometric toggle confirmation
            .alert("Enter Password", isPresented: $showBiometricToggle) {
                SecureField("Password", text: $biometricPassword)
                Button("Cancel", role: .cancel) {
                    biometricPassword = ""
                }
                Button(viewModel.isBiometricEnabled ? "Disable" : "Enable") {
                    Task {
                        await viewModel.toggleBiometric(
                            enabled: !viewModel.isBiometricEnabled,
                            password: biometricPassword
                        )
                        biometricPassword = ""
                    }
                }
            } message: {
                Text("Enter your vault password to \(viewModel.isBiometricEnabled ? "disable" : "enable") \(viewModel.biometryName).")
            }
            // Change password sheet
            .sheet(isPresented: $showChangePassword) {
                ChangePasswordSheet(viewModel: viewModel)
            }
            // Delete vault confirmation
            .alert("Delete Vault?", isPresented: $showDeleteVault) {
                SecureField("Password", text: $deletePassword)
                Button("Cancel", role: .cancel) {
                    deletePassword = ""
                }
                Button("Delete", role: .destructive) {
                    Task {
                        await viewModel.deleteVault(password: deletePassword)
                        deletePassword = ""
                        dismiss()
                    }
                }
            } message: {
                Text("This will permanently delete all encrypted files in your vault. Enter your password to confirm.")
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.error?.localizedDescription ?? "An error occurred")
            }
        }
    }

    private var biometricIcon: String {
        switch viewModel.biometryType {
        case .faceID:
            return "faceid"
        case .touchID:
            return "touchid"
        default:
            return "lock.circle"
        }
    }
}

// MARK: - Change Password Sheet

struct ChangePasswordSheet: View {
    @Bindable var viewModel: VaultViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("Current Password", text: $viewModel.currentPasswordForChange)
                        .textContentType(.password)
                } header: {
                    Text("Current Password")
                }

                Section {
                    SecureField("New Password", text: $viewModel.newPassword)
                        .textContentType(.newPassword)

                    SecureField("Confirm New Password", text: $viewModel.confirmNewPassword)
                        .textContentType(.newPassword)

                    if !viewModel.newPassword.isEmpty && !viewModel.confirmNewPassword.isEmpty {
                        if viewModel.newPassword != viewModel.confirmNewPassword {
                            Label("Passwords don't match", systemImage: "xmark.circle.fill")
                                .foregroundStyle(.red)
                                .font(.caption)
                        } else if viewModel.newPassword.count < 4 {
                            Label("Password must be at least 4 characters", systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                                .font(.caption)
                        } else {
                            Label("Passwords match", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                        }
                    }
                } header: {
                    Text("New Password")
                } footer: {
                    Text("All encrypted files will be re-encrypted with your new password. This may take a moment for large vaults.")
                }
            }
            .navigationTitle("Change Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        clearFields()
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        Task {
                            await viewModel.changePassword()
                            if viewModel.error == nil {
                                dismiss()
                            }
                        }
                    }
                    .disabled(!viewModel.canChangePassword || viewModel.isLoading)
                }
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.error?.localizedDescription ?? "An error occurred")
            }
            .overlay {
                if viewModel.isLoading {
                    ZStack {
                        Color.black.opacity(0.3)
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Re-encrypting vault...")
                                .font(.subheadline)
                                .foregroundStyle(.white)
                        }
                        .padding(24)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .ignoresSafeArea()
                }
            }
        }
    }

    private func clearFields() {
        viewModel.currentPasswordForChange = ""
        viewModel.newPassword = ""
        viewModel.confirmNewPassword = ""
    }
}

#Preview {
    VaultSettingsView(viewModel: VaultViewModel())
}
