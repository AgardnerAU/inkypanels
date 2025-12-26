import SwiftUI

/// Main vault view that routes between setup, unlock, and file list states
struct VaultView: View {
    @State private var viewModel = VaultViewModel()

    var body: some View {
        Group {
            switch viewModel.vaultState {
            case .notSetUp:
                NavigationStack {
                    VaultSetupView(viewModel: viewModel)
                }

            case .locked:
                NavigationStack {
                    VaultUnlockView(viewModel: viewModel)
                }

            case .unlocked:
                VaultFileListView(viewModel: viewModel)
            }
        }
        .task {
            await viewModel.configure()
        }
    }
}

#Preview {
    VaultView()
}
