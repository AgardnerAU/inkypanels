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
                        Label("Lock", systemImage: "lock.fill")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            viewModel.lock()
                        } label: {
                            Label("Lock Vault", systemImage: "lock.fill")
                        }

                        Divider()

                        Button {
                            viewModel.showSettings = true
                        } label: {
                            Label("Vault Settings", systemImage: "gear")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
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
                    VaultFileRowView(item: item, viewModel: viewModel)
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
    @Bindable var viewModel: VaultViewModel

    private let thumbnailSize = CGSize(width: 50, height: 70)

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            VaultThumbnailView(item: item, viewModel: viewModel, size: thumbnailSize)
                .clipShape(RoundedRectangle(cornerRadius: 4))

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

// MARK: - Vault Thumbnail View

struct VaultThumbnailView: View {
    let item: VaultItem
    @Bindable var viewModel: VaultViewModel
    let size: CGSize

    @State private var thumbnailData: Data?
    @State private var isLoading = true

    var body: some View {
        Group {
            if let thumbnailData,
               let uiImage = UIImage(data: thumbnailData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size.width, height: size.height)
                    .clipped()
            } else if isLoading {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.1))
                    .frame(width: size.width, height: size.height)
                    .overlay {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
            } else {
                // Placeholder for failed loads
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: size.width, height: size.height)
                    .overlay {
                        Image(systemName: item.fileType.icon)
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .task(priority: .userInitiated) {
            await loadThumbnail()
        }
    }

    private func loadThumbnail() async {
        // Check if already cached in viewModel
        if let cached = viewModel.thumbnailCache[item.id] {
            thumbnailData = cached
            isLoading = false
            return
        }

        // Load thumbnail through viewModel
        let data = await viewModel.loadThumbnail(for: item)
        thumbnailData = data
        isLoading = false
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
