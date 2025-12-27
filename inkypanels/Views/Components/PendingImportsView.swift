import SwiftUI

/// Sheet view for reviewing and importing files transferred via Finder
struct PendingImportsView: View {
    let files: [ComicFile]
    let isImporting: Bool
    let importProgress: Int
    let importTotal: Int
    let onImport: (Set<ComicFile.ID>) -> Void
    let onDelete: (Set<ComicFile.ID>) -> Void
    let onLoadFolderContents: (URL) async -> [ComicFile]
    let onDismiss: () -> Void

    @State private var selectedFiles: Set<ComicFile.ID>
    @State private var expandedFolders: Set<ComicFile.ID> = []
    @State private var folderContents: [ComicFile.ID: [ComicFile]] = [:]
    @State private var loadingFolders: Set<ComicFile.ID> = []
    @State private var showDeleteConfirmation = false

    init(
        files: [ComicFile],
        isImporting: Bool,
        importProgress: Int = 0,
        importTotal: Int = 0,
        onImport: @escaping (Set<ComicFile.ID>) -> Void,
        onDelete: @escaping (Set<ComicFile.ID>) -> Void,
        onLoadFolderContents: @escaping (URL) async -> [ComicFile],
        onDismiss: @escaping () -> Void
    ) {
        self.files = files
        self.isImporting = isImporting
        self.importProgress = importProgress
        self.importTotal = importTotal
        self.onImport = onImport
        self.onDelete = onDelete
        self.onLoadFolderContents = onLoadFolderContents
        self.onDismiss = onDismiss
        // Select all files by default
        self._selectedFiles = State(initialValue: Set(files.map { $0.id }))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isImporting {
                    importingView
                } else {
                    fileListView
                }
            }
            .navigationTitle("Import Files")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .confirmationDialog(
                "Delete \(selectedFiles.count) item\(selectedFiles.count == 1 ? "" : "s")?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    onDelete(selectedFiles)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete the selected files from your iPad. This cannot be undone.")
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") {
                onDismiss()
            }
            .disabled(isImporting)
        }

        ToolbarItem(placement: .confirmationAction) {
            Button("Import") {
                onImport(selectedFiles)
            }
            .disabled(isImporting || selectedFiles.isEmpty)
        }
    }

    // MARK: - Importing View

    private var importingView: some View {
        VStack(spacing: 20) {
            Spacer()

            if importTotal > 0 {
                ProgressView(value: Double(importProgress), total: Double(importTotal))
                    .progressViewStyle(.linear)
                    .frame(width: 200)
            } else {
                ProgressView()
                    .scaleEffect(1.5)
            }

            Text(importProgressText)
                .font(.headline)

            Spacer()
        }
    }

    private var importProgressText: String {
        if importTotal > 0 {
            return "Importing \(importProgress) of \(importTotal) files..."
        } else {
            return "Importing files..."
        }
    }

    // MARK: - File List View

    private var fileListView: some View {
        VStack(spacing: 0) {
            infoBanner
            selectAllToggle
            fileList
            footerView
        }
    }

    private var infoBanner: some View {
        HStack {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(.blue)

            Text("Select files to import into your library.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemBackground))
    }

    private var selectAllToggle: some View {
        HStack {
            Button {
                toggleSelectAll()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: allSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(allSelected ? .blue : .secondary)
                        .font(.title3)

                    Text(allSelected ? "Deselect All" : "Select All")
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                }
            }
            .buttonStyle(.plain)

            Spacer()

            if !selectedFiles.isEmpty {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete", systemImage: "trash")
                        .font(.subheadline)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
    }

    private var fileList: some View {
        List {
            ForEach(files) { file in
                fileRow(for: file, indentLevel: 0)

                // Show expanded folder contents
                if file.fileType == .folder && expandedFolders.contains(file.id) {
                    if loadingFolders.contains(file.id) {
                        HStack {
                            Spacer()
                            ProgressView()
                                .padding(.leading, 44)
                            Spacer()
                        }
                        .listRowBackground(Color(.secondarySystemBackground))
                    } else if let contents = folderContents[file.id] {
                        ForEach(contents) { childFile in
                            fileRow(for: childFile, indentLevel: 1, parentId: file.id)
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    private func fileRow(for file: ComicFile, indentLevel: Int, parentId: ComicFile.ID? = nil) -> some View {
        HStack(spacing: 12) {
            // Indentation for nested files
            if indentLevel > 0 {
                Spacer()
                    .frame(width: CGFloat(indentLevel) * 24)
            }

            // Selection checkbox
            Button {
                toggleSelection(for: file, parentId: parentId)
            } label: {
                Image(systemName: selectedFiles.contains(file.id) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selectedFiles.contains(file.id) ? .blue : .secondary)
                    .font(.title2)
            }
            .buttonStyle(.plain)

            // Folder expansion chevron (for folders only)
            if file.fileType == .folder {
                Button {
                    toggleFolderExpansion(file)
                } label: {
                    Image(systemName: expandedFolders.contains(file.id) ? "chevron.down" : "chevron.right")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                        .frame(width: 20)
                }
                .buttonStyle(.plain)
            } else {
                Spacer()
                    .frame(width: 20)
            }

            // File info
            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                    .font(.body)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if file.fileType == .folder {
                        Text("\(file.containedFileCount ?? 0) files")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(file.fileType.rawValue.uppercased())
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.secondary.opacity(0.2))
                            .cornerRadius(2)
                    }

                    Text(formattedSize(file.fileSize))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Folder icon for folders
            if file.fileType == .folder {
                Image(systemName: "folder.fill")
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            toggleSelection(for: file, parentId: parentId)
        }
        .listRowBackground(indentLevel > 0 ? Color(.secondarySystemBackground) : nil)
    }

    private var footerView: some View {
        HStack {
            Text(selectionSummaryText)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Text(formattedSelectedSize)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
    }

    // MARK: - Computed Properties

    private var allSelected: Bool {
        let allIds = getAllSelectableIds()
        return !allIds.isEmpty && allIds.isSubset(of: selectedFiles)
    }

    private func getAllSelectableIds() -> Set<ComicFile.ID> {
        var ids = Set(files.map { $0.id })
        for (_, contents) in folderContents {
            ids.formUnion(contents.map { $0.id })
        }
        return ids
    }

    private var selectedFileCount: Int {
        var count = 0
        for id in selectedFiles {
            if let file = findFile(by: id) {
                if file.fileType == .folder {
                    count += file.containedFileCount ?? 1
                } else {
                    count += 1
                }
            }
        }
        return count
    }

    private var totalFileCount: Int {
        var count = 0
        for file in files {
            if file.fileType == .folder {
                count += file.containedFileCount ?? 1
            } else {
                count += 1
            }
        }
        return count
    }

    private var selectionSummaryText: String {
        "\(selectedFileCount) of \(totalFileCount) files selected"
    }

    private var formattedSelectedSize: String {
        var totalBytes: Int64 = 0
        for id in selectedFiles {
            if let file = findFile(by: id) {
                totalBytes += file.fileSize
            }
        }
        return ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
    }

    private func formattedSize(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private func findFile(by id: ComicFile.ID) -> ComicFile? {
        if let file = files.first(where: { $0.id == id }) {
            return file
        }
        for (_, contents) in folderContents {
            if let file = contents.first(where: { $0.id == id }) {
                return file
            }
        }
        return nil
    }

    // MARK: - Actions

    private func toggleSelectAll() {
        let allIds = getAllSelectableIds()
        if allSelected {
            selectedFiles.removeAll()
        } else {
            selectedFiles = allIds
        }
    }

    private func toggleSelection(for file: ComicFile, parentId: ComicFile.ID?) {
        if selectedFiles.contains(file.id) {
            selectedFiles.remove(file.id)
            // If this is a folder, also deselect all its children
            if file.fileType == .folder, let contents = folderContents[file.id] {
                for child in contents {
                    selectedFiles.remove(child.id)
                }
            }
        } else {
            selectedFiles.insert(file.id)
            // If this is a folder, also select all its children
            if file.fileType == .folder, let contents = folderContents[file.id] {
                for child in contents {
                    selectedFiles.insert(child.id)
                }
            }
        }
    }

    private func toggleFolderExpansion(_ folder: ComicFile) {
        if expandedFolders.contains(folder.id) {
            expandedFolders.remove(folder.id)
        } else {
            expandedFolders.insert(folder.id)
            // Load contents if not already loaded
            if folderContents[folder.id] == nil {
                loadFolderContents(folder)
            }
        }
    }

    private func loadFolderContents(_ folder: ComicFile) {
        loadingFolders.insert(folder.id)
        Task {
            let contents = await onLoadFolderContents(folder.url)
            await MainActor.run {
                folderContents[folder.id] = contents
                loadingFolders.remove(folder.id)
                // Auto-select children if parent is selected
                if selectedFiles.contains(folder.id) {
                    for child in contents {
                        selectedFiles.insert(child.id)
                    }
                }
            }
        }
    }
}

#Preview {
    PendingImportsView(
        files: [
            ComicFile(
                url: URL(fileURLWithPath: "/test1.cbz"),
                name: "Batman: Year One",
                fileType: .cbz,
                fileSize: 50_000_000,
                modifiedDate: Date()
            ),
            ComicFile(
                url: URL(fileURLWithPath: "/folder"),
                name: "My Comics",
                fileType: .folder,
                fileSize: 150_000_000,
                modifiedDate: Date(),
                containedFileCount: 5
            ),
            ComicFile(
                url: URL(fileURLWithPath: "/test2.cbr"),
                name: "Spider-Man: Blue",
                fileType: .cbr,
                fileSize: 75_000_000,
                modifiedDate: Date()
            )
        ],
        isImporting: false,
        onImport: { _ in },
        onDelete: { _ in },
        onLoadFolderContents: { _ in [] },
        onDismiss: {}
    )
}
