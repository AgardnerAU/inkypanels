import SwiftUI

/// View for initial vault setup
struct VaultSetupView: View {
    @Bindable var viewModel: VaultViewModel
    @FocusState private var focusedField: Field?

    enum Field {
        case password
        case confirm
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(Color.accentColor)

                    Text("Create Your Vault")
                        .font(.title.bold())

                    Text("Set a password to protect your private files. Files in the vault are encrypted and hidden from normal browsing.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 40)

                // Password fields
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Password")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)

                        SecureField("Enter password", text: $viewModel.setupPassword)
                            .textContentType(.newPassword)
                            .focused($focusedField, equals: .password)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .confirm }
                            .padding()
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Confirm Password")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)

                        SecureField("Confirm password", text: $viewModel.confirmPassword)
                            .textContentType(.newPassword)
                            .focused($focusedField, equals: .confirm)
                            .submitLabel(.done)
                            .onSubmit {
                                focusedField = nil
                                if viewModel.canSetupVault {
                                    Task { await viewModel.setupVault() }
                                }
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        if !viewModel.setupPassword.isEmpty && !viewModel.confirmPassword.isEmpty {
                            if viewModel.setupPassword != viewModel.confirmPassword {
                                Label("Passwords don't match", systemImage: "xmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            } else if viewModel.setupPassword.count < 4 {
                                Label("Password must be at least 4 characters", systemImage: "exclamationmark.triangle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            } else {
                                Label("Passwords match", systemImage: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)

                // Biometric toggle
                if viewModel.isBiometricAvailable {
                    Toggle(isOn: $viewModel.enableBiometricOnSetup) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Enable \(viewModel.biometryName)")
                                    .font(.body)
                                Text("Quick unlock without entering password")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: biometricIcon)
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 24)
                }

                // Create button
                Button {
                    focusedField = nil
                    Task { await viewModel.setupVault() }
                } label: {
                    if viewModel.isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Create Vault")
                            .font(.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(viewModel.canSetupVault ? Color.accentColor : Color.gray)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .disabled(!viewModel.canSetupVault || viewModel.isLoading)
                .padding(.horizontal, 24)

                Spacer(minLength: 40)
            }
        }
        .navigationTitle("Vault")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Setup Failed", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.error?.localizedDescription ?? "An error occurred")
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

#Preview {
    NavigationStack {
        VaultSetupView(viewModel: VaultViewModel())
    }
}
