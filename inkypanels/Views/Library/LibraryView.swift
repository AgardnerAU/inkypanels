import SwiftUI

struct LibraryView: View {
    @State private var viewModel = LibraryViewModel()
    @State private var navigationPath = NavigationPath()

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
        }
        .task {
            await viewModel.loadFiles()
        }
    }

    // MARK: - Subviews

    private var fileList: some View {
        List {
            ForEach(viewModel.files) { file in
                if file.fileType == .folder {
                    Button {
                        viewModel.navigateToFolder(file)
                    } label: {
                        FileRowView(file: file)
                    }
                    .buttonStyle(.plain)
                } else {
                    NavigationLink(value: file) {
                        FileRowView(file: file)
                    }
                }
            }
            .onDelete(perform: deleteFiles)
        }
        .listStyle(.plain)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            if viewModel.canNavigateUp() {
                Button {
                    viewModel.navigateUp()
                } label: {
                    Label("Back", systemImage: "chevron.left")
                }
            }
        }

        ToolbarItem(placement: .primaryAction) {
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

    // MARK: - Computed Properties

    private var navigationTitle: String {
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
