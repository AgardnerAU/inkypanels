import SwiftUI

/// View for displaying vault files when unlocked
struct VaultFileListView: View {
    @Bindable var viewModel: VaultViewModel
    @State private var showRemoveConfirmation = false
    @State private var itemToRemove: VaultItem?
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if viewModel.isLoading && viewModel.vaultItems.isEmpty {
                    LoadingView("Loading vault...")
                } else if viewModel.vaultItems.isEmpty {
                    emptyState
                } else {
                    fileList
                }
            }
            .navigationTitle("Vault")
            .navigationDestination(for: VaultItem.self) { item in
                VaultReaderView(viewModel: viewModel, item: item)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        viewModel.lock()
                    } label: {
                        Image(systemName: "lock.fill")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.showSettings = true
                    } label: {
                        Image(systemName: "gear")
                    }
                }
            }
            .sheet(isPresented: $viewModel.showSettings) {
                VaultSettingsView(viewModel: viewModel)
            }
            .alert("Remove from Vault?", isPresented: $showRemoveConfirmation) {
                Button("Cancel", role: .cancel) {
                    itemToRemove = nil
                }
                Button("Remove", role: .destructive) {
                    if let item = itemToRemove {
                        Task { await viewModel.removeFile(item) }
                    }
                    itemToRemove = nil
                }
            } message: {
                if let item = itemToRemove {
                    Text("'\(item.originalName)' will be decrypted and moved back to your library.")
                }
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.error?.localizedDescription ?? "An error occurred")
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Your Vault is Empty", systemImage: "lock.open")
        } description: {
            Text("Swipe right on files in your library and tap 'Move to Vault' to protect them with encryption.")
        }
    }

    private var fileList: some View {
        List {
            ForEach(viewModel.vaultItems) { item in
                Button {
                    navigationPath.append(item)
                } label: {
                    VaultFileRowView(item: item)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        itemToRemove = item
                        showRemoveConfirmation = true
                    } label: {
                        Label("Remove", systemImage: "arrow.uturn.left")
                    }
                    .tint(.orange)
                }
            }
        }
        .listStyle(.plain)
        .refreshable {
            await viewModel.checkVaultStatus()
        }
    }
}

// MARK: - Vault File Row

struct VaultFileRowView: View {
    let item: VaultItem

    private let iconSize: CGFloat = 50

    var body: some View {
        HStack(spacing: 12) {
            // File type icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray5))
                    .frame(width: iconSize, height: iconSize)

                Image(systemName: item.fileType.icon)
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.originalName)
                    .font(.headline)
                    .lineLimit(2)
                    .foregroundStyle(.primary)

                HStack(spacing: 8) {
                    // File size
                    Text(ByteCountFormatter.string(fromByteCount: item.fileSize, countStyle: .file))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    // Added date
                    Text(item.addedDate, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                // Encrypted indicator
                Label("Encrypted", systemImage: "lock.fill")
                    .font(.caption2)
                    .foregroundStyle(.green)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

// MARK: - Vault Reader View

struct VaultReaderView: View {
    @Bindable var viewModel: VaultViewModel
    let item: VaultItem
    @State private var decryptedURL: URL?
    @State private var isLoading = true
    @State private var error: VaultError?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            if isLoading {
                LoadingView("Decrypting...")
            } else if let url = decryptedURL {
                ReaderView(comic: makeComicFile(from: url))
            } else if let error {
                ErrorView(error) {
                    dismiss()
                }
            }
        }
        .task {
            await decryptFile()
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private func makeComicFile(from url: URL) -> ComicFile {
        ComicFile(
            id: item.id,
            url: url,
            name: (item.originalName as NSString).deletingPathExtension,
            fileType: item.fileType,
            fileSize: item.fileSize,
            modifiedDate: item.addedDate,
            pageCount: nil,
            readingProgress: nil
        )
    }

    private func decryptFile() async {
        isLoading = true
        if let url = await viewModel.openFile(item) {
            decryptedURL = url
        } else {
            error = viewModel.error ?? .decryptionFailed(underlying: NSError(
                domain: "VaultReaderView",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to decrypt file"]
            ))
        }
        isLoading = false
    }
}

#Preview {
    VaultFileListView(viewModel: VaultViewModel())
}
