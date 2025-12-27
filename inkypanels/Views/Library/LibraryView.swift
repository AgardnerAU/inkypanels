import SwiftData
import SwiftUI

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = LibraryViewModel()
    @State private var navigationPath = NavigationPath()
    @State private var showDeleteConfirmation = false
    @State private var showImportPicker = false
    @State private var showPendingImports = false

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if viewModel.isLoading {
                    LoadingView("Loading library...")
                } else if let error = viewModel.error {
                    ErrorView(error) {
                        Task { await viewModel.loadFiles() }
                    }
                } else if viewModel.files.isEmpty {
                    if viewModel.hasPendingImports {
                        emptyStateWithPendingImports
                    } else {
                        ContentUnavailableView(
                            "No Comics",
                            systemImage: "book.closed",
                            description: Text("Add comics to the Comics folder using the Files app")
                        )
                    }
                } else {
                    fileList
                }
            }
            .navigationTitle(navigationTitle)
            .toolbar { toolbarContent }
            .navigationDestination(for: ComicFile.self) { file in
                if file.fileType == .folder {
                    // Handle folder navigation inline
                    EmptyView()
                } else {
                    ReaderView(comic: file)
                }
            }
            .refreshable {
                await viewModel.refresh()
                await viewModel.checkForPendingImports()
            }
            .confirmationDialog(
                "Delete \(viewModel.selectedCount) item\(viewModel.selectedCount == 1 ? "" : "s")?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    Task { await viewModel.deleteSelected() }
                }
                Button("Cancel", role: .cancel) {}
            }
            .sheet(isPresented: $showImportPicker) {
                importPickerSheet
            }
            .sheet(isPresented: $showPendingImports) {
                pendingImportsSheet
            }
        }
        .task {
            viewModel.configureFavouriteService(modelContext: modelContext)
            await viewModel.loadFiles()
            await viewModel.checkForPendingImports()
        }
    }

    // MARK: - Subviews

    private var emptyStateWithPendingImports: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "square.and.arrow.down.on.square.fill")
                .font(.system(size: 60))
                .foregroundStyle(.blue)

            VStack(spacing: 8) {
                Text("Files Ready to Import")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text(pendingImportsSummary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button {
                showPendingImports = true
            } label: {
                Text("Import Files")
                    .fontWeight(.semibold)
                    .frame(minWidth: 200)
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
        .padding()
    }

    private var pendingImportsSummary: String {
        let (folderCount, totalFileCount) = pendingImportCounts
        let individualFileCount = totalFileCount - pendingContainedFileCount

        if folderCount == 0 {
            // Only individual files
            return "\(totalFileCount) file\(totalFileCount == 1 ? " was" : "s were") transferred via Finder"
        } else if individualFileCount == 0 {
            // Only folders
            let folderText = folderCount == 1 ? "1 folder" : "\(folderCount) folders"
            let fileText = totalFileCount == 1 ? "1 file" : "\(totalFileCount) files"
            return "\(folderText) with \(fileText) transferred via Finder"
        } else {
            // Mix of folders and individual files
            let folderText = folderCount == 1 ? "1 folder" : "\(folderCount) folders"
            let fileText = totalFileCount == 1 ? "1 file" : "\(totalFileCount) files"
            return "\(folderText) and \(fileText) transferred via Finder"
        }
    }

    private var pendingImportsBannerTitle: String {
        let (folderCount, totalFileCount) = pendingImportCounts
        let individualFileCount = totalFileCount - pendingContainedFileCount

        if folderCount == 0 {
            // Only individual files
            return "\(totalFileCount) file\(totalFileCount == 1 ? "" : "s") ready to import"
        } else if individualFileCount == 0 {
            // Only folders
            let folderText = folderCount == 1 ? "1 folder" : "\(folderCount) folders"
            let fileText = totalFileCount == 1 ? "1 file" : "\(totalFileCount) files"
            return "\(folderText) with \(fileText) ready to import"
        } else {
            // Mix of folders and individual files
            let folderText = folderCount == 1 ? "1 folder" : "\(folderCount) folders"
            let fileText = totalFileCount == 1 ? "1 file" : "\(totalFileCount) files"
            return "\(folderText) and \(fileText) ready to import"
        }
    }

    private var pendingImportCounts: (folderCount: Int, totalFileCount: Int) {
        let imports = viewModel.pendingImports
        let folders = imports.filter { $0.fileType == .folder }
        let individualFiles = imports.filter { $0.fileType != .folder }

        let folderCount = folders.count
        let individualFileCount = individualFiles.count
        let containedFileCount = folders.compactMap(\.containedFileCount).reduce(0, +)
        let totalFileCount = individualFileCount + containedFileCount

        return (folderCount, totalFileCount)
    }

    private var pendingContainedFileCount: Int {
        viewModel.pendingImports
            .filter { $0.fileType == .folder }
            .compactMap(\.containedFileCount)
            .reduce(0, +)
    }

    private var fileList: some View {
        List {
            if viewModel.hasPendingImports && !viewModel.canNavigateUp() {
                pendingImportsBanner
            }

            ForEach(viewModel.files) { file in
                if viewModel.isSelecting {
                    selectableRow(for: file)
                } else if file.fileType == .folder {
                    Button {
                        viewModel.navigateToFolder(file)
                    } label: {
                        FileRowView(file: file, isFavourite: viewModel.isFavourite(file))
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .leading) {
                        favouriteSwipeAction(for: file)
                        vaultSwipeAction(for: file)
                    }
                } else {
                    NavigationLink(value: file) {
                        FileRowView(file: file, isFavourite: viewModel.isFavourite(file))
                    }
                    .swipeActions(edge: .leading) {
                        favouriteSwipeAction(for: file)
                        vaultSwipeAction(for: file)
                    }
                }
            }
            .onDelete(perform: viewModel.isSelecting ? nil : deleteFiles)
        }
        .listStyle(.plain)
    }

    private func favouriteSwipeAction(for file: ComicFile) -> some View {
        Button {
            Task { await viewModel.toggleFavourite(file) }
        } label: {
            Label(
                viewModel.isFavourite(file) ? "Unfavourite" : "Favourite",
                systemImage: viewModel.isFavourite(file) ? "star.slash" : "star.fill"
            )
        }
        .tint(.yellow)
    }

    private func vaultSwipeAction(for file: ComicFile) -> some View {
        Button {
            Task { await viewModel.moveToVault(file) }
        } label: {
            Label("Move to Vault", systemImage: "lock.fill")
        }
        .tint(.purple)
    }

    private func selectableRow(for file: ComicFile) -> some View {
        Button {
            viewModel.toggleFileSelection(file)
        } label: {
            HStack {
                Image(systemName: viewModel.selectedFiles.contains(file.id) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(viewModel.selectedFiles.contains(file.id) ? .blue : .secondary)
                    .font(.title2)

                FileRowView(file: file)
            }
        }
        .buttonStyle(.plain)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            if viewModel.isSelecting {
                Button("Cancel") {
                    viewModel.toggleSelection()
                }
            } else if viewModel.canNavigateUp() {
                Button {
                    viewModel.navigateUp()
                } label: {
                    Label("Back", systemImage: "chevron.left")
                }
            }
        }

        ToolbarItem(placement: .principal) {
            if viewModel.isSelecting && viewModel.hasSelection {
                Text("\(viewModel.selectedCount) selected")
                    .font(.headline)
            }
        }

        ToolbarItemGroup(placement: .primaryAction) {
            if viewModel.isSelecting {
                Button {
                    if viewModel.selectedFiles.count == viewModel.files.count {
                        viewModel.deselectAll()
                    } else {
                        viewModel.selectAll()
                    }
                } label: {
                    Text(viewModel.selectedFiles.count == viewModel.files.count ? "Deselect All" : "Select All")
                }

                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .disabled(!viewModel.hasSelection)
            } else {
                Button {
                    showImportPicker = true
                } label: {
                    Label("Import", systemImage: "plus")
                }

                Button {
                    Task {
                        await viewModel.refresh()
                        await viewModel.checkForPendingImports()
                    }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }

                Button {
                    viewModel.toggleSelection()
                } label: {
                    Label("Select", systemImage: "checkmark.circle")
                }

                Menu {
                    Picker("Sort By", selection: Binding(
                        get: { viewModel.sortOrder },
                        set: { viewModel.setSortOrder($0) }
                    )) {
                        ForEach(LibraryViewModel.SortOrder.allCases, id: \.self) { order in
                            Text(order.label).tag(order)
                        }
                    }
                } label: {
                    Label("Sort", systemImage: "arrow.up.arrow.down")
                }
            }
        }
    }

    // MARK: - Import Picker

    private var importPickerSheet: some View {
        DocumentPicker { urls in
            showImportPicker = false
            Task { await viewModel.importFiles(urls) }
        } onCancel: {
            showImportPicker = false
        }
    }

    // MARK: - Pending Imports

    private var pendingImportsBanner: some View {
        Button {
            showPendingImports = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "square.and.arrow.down.on.square.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)

                VStack(alignment: .leading, spacing: 2) {
                    Text(pendingImportsBannerTitle)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)

                    Text("Transferred via Finder")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 8)
        }
        .listRowBackground(Color.blue.opacity(0.1))
    }

    private var pendingImportsSheet: some View {
        PendingImportsView(
            files: viewModel.pendingImports,
            isImporting: viewModel.isImporting,
            onImportAll: {
                Task {
                    await viewModel.importAllPendingFiles()
                    showPendingImports = false
                }
            },
            onDismiss: {
                showPendingImports = false
            }
        )
    }

    // MARK: - Computed Properties

    private var navigationTitle: String {
        if viewModel.isSelecting {
            return "Select Items"
        }
        if viewModel.canNavigateUp() {
            return viewModel.currentDirectory.lastPathComponent
        }
        return "Library"
    }

    // MARK: - Actions

    private func deleteFiles(at offsets: IndexSet) {
        Task {
            for index in offsets {
                let file = viewModel.files[index]
                try? await viewModel.deleteFile(file)
            }
        }
    }
}

#Preview {
    LibraryView()
}
