import SwiftUI

/// View for unlocking the vault
struct VaultUnlockView: View {
    @Bindable var viewModel: VaultViewModel
    @FocusState private var isPasswordFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(Color.accentColor)

                    Text("Vault Locked")
                        .font(.title.bold())

                    Text("Enter your password to access your protected files.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 60)

                // Biometric button (if enabled)
                if viewModel.isBiometricEnabled {
                    Button {
                        Task { await viewModel.unlockWithBiometric() }
                    } label: {
                        VStack(spacing: 12) {
                            Image(systemName: biometricIcon)
                                .font(.system(size: 44))

                            Text("Unlock with \(viewModel.biometryName)")
                                .font(.subheadline)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 120)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .disabled(viewModel.isLoading)
                    .padding(.horizontal, 24)

                    Text("or enter password")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Password field
                VStack(spacing: 16) {
                    SecureField("Password", text: $viewModel.unlockPassword)
                        .textContentType(.password)
                        .focused($isPasswordFocused)
                        .submitLabel(.go)
                        .onSubmit {
                            if viewModel.canUnlock {
                                Task { await viewModel.unlockWithPassword() }
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    Button {
                        isPasswordFocused = false
                        Task { await viewModel.unlockWithPassword() }
                    } label: {
                        if viewModel.isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Unlock")
                                .font(.headline)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(viewModel.canUnlock ? Color.accentColor : Color.gray)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .disabled(!viewModel.canUnlock || viewModel.isLoading)
                }
                .padding(.horizontal, 24)

                Spacer(minLength: 40)
            }
        }
        .navigationTitle("Vault")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // Auto-trigger biometric on appear if enabled
            if viewModel.isBiometricEnabled && !viewModel.isLoading {
                try? await Task.sleep(for: .milliseconds(300))
                await viewModel.unlockWithBiometric()
            }
        }
        .alert("Unlock Failed", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
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

    private var errorMessage: String {
        guard let error = viewModel.error else {
            return "An error occurred"
        }

        switch error {
        case .incorrectPassword:
            return "The password you entered is incorrect. Please try again."
        case .biometricFailed:
            return "\(viewModel.biometryName) authentication failed. Please try again or use your password."
        case .biometricNotAvailable:
            return "\(viewModel.biometryName) is not available. Please use your password."
        default:
            return error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        VaultUnlockView(viewModel: VaultViewModel())
    }
}
