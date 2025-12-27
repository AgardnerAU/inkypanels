import SwiftUI

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

/// Shared context menu content for group headers
struct GroupContextMenuContent: View {
    let group: DisplayGroup
    let onSaveAutoGroup: (DisplayGroup) -> Void
    let onDeleteGroup: (UUID) -> Void

    var body: some View {
        if group.isAutomatic {
            Button {
                onSaveAutoGroup(group)
            } label: {
                Label("Save as Collection", systemImage: "folder.badge.plus")
            }
        } else {
            // Manual group - extract UUID from ID
            if let uuidString = group.id.replacingOccurrences(of: "manual-", with: "").nilIfEmpty,
               let uuid = UUID(uuidString: uuidString) {
                Button(role: .destructive) {
                    onDeleteGroup(uuid)
                } label: {
                    Label("Delete Group", systemImage: "trash")
                }
            }
        }
    }
}

/// A header view for a collapsible group section
struct GroupHeaderView: View {
    let group: DisplayGroup
    let isExpanded: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                // Group thumbnail (first file's cover)
                if let firstFile = group.files.first {
                    ThumbnailView(
                        file: firstFile,
                        size: CGSize(width: 40, height: 56)
                    )
                } else {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(width: 40, height: 56)
                        .overlay {
                            Image(systemName: "square.stack.3d.up.fill")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(group.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text("\(group.fileCount) item\(group.fileCount == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if group.isAutomatic {
                            Text("Auto")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.15))
                                .foregroundStyle(.blue)
                                .cornerRadius(4)
                        }
                    }
                }

                Spacer()

                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .animation(.easeInOut(duration: 0.2), value: isExpanded)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// List view with grouped files in collapsible sections
struct GroupedLibraryListView: View {
    @Bindable var viewModel: LibraryViewModel
    let onNavigateToFolder: (ComicFile) -> Void
    let onDeleteFile: (ComicFile) async throws -> Void
    let contextMenuActions: (ComicFile) -> AnyView
    let onSaveAutoGroup: (DisplayGroup) -> Void
    let onDeleteGroup: (UUID) -> Void

    var body: some View {
        List {
            // Grouped files
            ForEach(viewModel.displayGroups) { group in
                Section {
                    if viewModel.isGroupExpanded(group.id) {
                        ForEach(group.files) { file in
                            fileRow(for: file)
                        }
                    }
                } header: {
                    GroupHeaderView(
                        group: group,
                        isExpanded: viewModel.isGroupExpanded(group.id),
                        onToggle: { viewModel.toggleGroupExpanded(group.id) }
                    )
                    .padding(.vertical, 4)
                    .contextMenu {
                        GroupContextMenuContent(
                            group: group,
                            onSaveAutoGroup: onSaveAutoGroup,
                            onDeleteGroup: onDeleteGroup
                        )
                    }
                }
            }

            // Ungrouped files section
            if !viewModel.ungroupedFiles.isEmpty {
                Section {
                    ForEach(viewModel.ungroupedFiles) { file in
                        fileRow(for: file)
                    }
                } header: {
                    HStack {
                        Text("Other")
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Spacer()

                        Text("\(viewModel.ungroupedFiles.count) item\(viewModel.ungroupedFiles.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .listStyle(.plain)
    }

    @ViewBuilder
    private func fileRow(for file: ComicFile) -> some View {
        if file.fileType == .folder {
            Button {
                onNavigateToFolder(file)
            } label: {
                FileRowView(file: file, isFavourite: viewModel.isFavourite(file))
            }
            .buttonStyle(.plain)
            .contextMenu { contextMenuActions(file) }
        } else {
            NavigationLink(value: file) {
                FileRowView(file: file, isFavourite: viewModel.isFavourite(file))
            }
            .contextMenu { contextMenuActions(file) }
        }
    }
}

/// Grid view with grouped files in collapsible sections
struct GroupedLibraryGridView: View {
    @Bindable var viewModel: LibraryViewModel
    let tileSize: TileSize
    let onNavigateToFolder: (ComicFile) -> Void
    let contextMenuActions: (ComicFile) -> AnyView
    let onSaveAutoGroup: (DisplayGroup) -> Void
    let onDeleteGroup: (UUID) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                // Grouped files
                ForEach(viewModel.displayGroups) { group in
                    VStack(alignment: .leading, spacing: 12) {
                        GroupHeaderView(
                            group: group,
                            isExpanded: viewModel.isGroupExpanded(group.id),
                            onToggle: { viewModel.toggleGroupExpanded(group.id) }
                        )
                        .padding(.horizontal)
                        .contextMenu {
                            GroupContextMenuContent(
                                group: group,
                                onSaveAutoGroup: onSaveAutoGroup,
                                onDeleteGroup: onDeleteGroup
                            )
                        }

                        if viewModel.isGroupExpanded(group.id) {
                            LazyVGrid(
                                columns: [GridItem(.adaptive(minimum: tileSize.minColumnWidth))],
                                spacing: 16
                            ) {
                                ForEach(group.files) { file in
                                    fileTile(for: file)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }

                    Divider()
                        .padding(.horizontal)
                }

                // Ungrouped files section
                if !viewModel.ungroupedFiles.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Other")
                                .font(.headline)

                            Spacer()

                            Text("\(viewModel.ungroupedFiles.count) item\(viewModel.ungroupedFiles.count == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal)

                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: tileSize.minColumnWidth))],
                            spacing: 16
                        ) {
                            ForEach(viewModel.ungroupedFiles) { file in
                                fileTile(for: file)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
    }

    @ViewBuilder
    private func fileTile(for file: ComicFile) -> some View {
        if file.fileType == .folder {
            Button {
                onNavigateToFolder(file)
            } label: {
                FileTileView(
                    file: file,
                    tileSize: tileSize,
                    isFavourite: viewModel.isFavourite(file)
                )
            }
            .buttonStyle(.plain)
            .contextMenu { contextMenuActions(file) }
        } else {
            NavigationLink(value: file) {
                FileTileView(
                    file: file,
                    tileSize: tileSize,
                    isFavourite: viewModel.isFavourite(file)
                )
            }
            .contextMenu { contextMenuActions(file) }
        }
    }
}

#Preview("Group Header") {
    VStack(spacing: 20) {
        GroupHeaderView(
            group: DisplayGroup(
                id: "test",
                name: "Batman",
                files: [
                    ComicFile(
                        url: URL(fileURLWithPath: "/Batman Vol. 1.cbz"),
                        name: "Batman Vol. 1",
                        fileType: .cbz,
                        fileSize: 50_000_000,
                        modifiedDate: Date()
                    ),
                    ComicFile(
                        url: URL(fileURLWithPath: "/Batman Vol. 2.cbz"),
                        name: "Batman Vol. 2",
                        fileType: .cbz,
                        fileSize: 48_000_000,
                        modifiedDate: Date()
                    )
                ],
                isAutomatic: true
            ),
            isExpanded: true,
            onToggle: {}
        )

        GroupHeaderView(
            group: DisplayGroup(
                id: "test2",
                name: "Spider-Man Collection",
                files: [
                    ComicFile(
                        url: URL(fileURLWithPath: "/Spider-Man.cbz"),
                        name: "Spider-Man",
                        fileType: .cbz,
                        fileSize: 30_000_000,
                        modifiedDate: Date()
                    )
                ],
                isAutomatic: false
            ),
            isExpanded: false,
            onToggle: {}
        )
    }
    .padding()
}
