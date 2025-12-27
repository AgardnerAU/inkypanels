import SwiftUI

/// Sheet view for reviewing and importing files transferred via Finder
struct PendingImportsView: View {
    let files: [ComicFile]
    let isImporting: Bool
    let importProgress: Int
    let importTotal: Int
    let onImportAll: () -> Void
    let onDismiss: () -> Void

    @State private var selectedFiles: Set<ComicFile.ID>

    init(
        files: [ComicFile],
        isImporting: Bool,
        importProgress: Int = 0,
        importTotal: Int = 0,
        onImportAll: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.files = files
        self.isImporting = isImporting
        self.importProgress = importProgress
        self.importTotal = importTotal
        self.onImportAll = onImportAll
        self.onDismiss = onDismiss
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
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onDismiss()
                    }
                    .disabled(isImporting)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Import All") {
                        onImportAll()
                    }
                    .disabled(isImporting || files.isEmpty)
                }
            }
        }
    }

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

    private var fileListView: some View {
        VStack(spacing: 0) {
            // Info banner
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(.blue)

                Text("These files were transferred to your iPad and are ready to import into your library.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .padding()
            .background(Color(.secondarySystemBackground))

            // File list
            List {
                ForEach(files) { file in
                    FileRowView(file: file)
                }
            }
            .listStyle(.plain)

            // Summary footer
            HStack {
                Text(importSummaryText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(formattedTotalSize)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
        }
    }

    /// Summary text showing total files including those in folders
    private var importSummaryText: String {
        let folders = files.filter { $0.fileType == .folder }
        let individualFiles = files.filter { $0.fileType != .folder }
        let containedFileCount = folders.compactMap(\.containedFileCount).reduce(0, +)
        let totalFileCount = individualFiles.count + containedFileCount

        if folders.isEmpty {
            return "\(totalFileCount) file\(totalFileCount == 1 ? "" : "s") ready to import"
        } else {
            let folderText = folders.count == 1 ? "1 folder" : "\(folders.count) folders"
            return "\(folderText) with \(totalFileCount) file\(totalFileCount == 1 ? "" : "s") ready to import"
        }
    }

    /// Total count of all files including those in folders
    private var totalFileCount: Int {
        let folders = files.filter { $0.fileType == .folder }
        let individualFiles = files.filter { $0.fileType != .folder }
        let containedFileCount = folders.compactMap(\.containedFileCount).reduce(0, +)
        return individualFiles.count + containedFileCount
    }

    private var formattedTotalSize: String {
        let totalBytes = files.reduce(0) { $0 + $1.fileSize }
        return ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
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
                url: URL(fileURLWithPath: "/test2.cbr"),
                name: "Spider-Man: Blue",
                fileType: .cbr,
                fileSize: 75_000_000,
                modifiedDate: Date()
            )
        ],
        isImporting: false,
        onImportAll: {},
        onDismiss: {}
    )
}
