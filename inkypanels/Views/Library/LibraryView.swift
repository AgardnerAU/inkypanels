import SwiftData
import SwiftUI

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = LibraryViewModel()
    @State private var navigationPath = NavigationPath()
    @State private var showDeleteConfirmation = false

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
                    ContentUnavailableView(
                        "No Comics",
                        systemImage: "book.closed",
                        description: Text("Add comics to the Comics folder using the Files app")
                    )
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
        }
        .task {
            viewModel.configureFavouriteService(modelContext: modelContext)
            await viewModel.loadFiles()
        }
    }

    // MARK: - Subviews

    private var fileList: some View {
        List {
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
                    }
                } else {
                    NavigationLink(value: file) {
                        FileRowView(file: file, isFavourite: viewModel.isFavourite(file))
                    }
                    .swipeActions(edge: .leading) {
                        favouriteSwipeAction(for: file)
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
