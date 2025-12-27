import SwiftUI

/// View for managing manual groups (collections)
struct GroupManagementView: View {
    @Bindable var viewModel: LibraryViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedGroup: GroupRecord?
    @State private var showRenameAlert = false
    @State private var renameText = ""
    @State private var groupToRename: GroupRecord?

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.manualGroups.isEmpty {
                    emptyState
                } else {
                    groupList
                }
            }
            .navigationTitle("Collections")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                        .disabled(viewModel.manualGroups.isEmpty)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Rename Collection", isPresented: $showRenameAlert) {
                TextField("Name", text: $renameText)
                Button("Cancel", role: .cancel) {
                    renameText = ""
                    groupToRename = nil
                }
                Button("Rename") {
                    if let group = groupToRename {
                        Task {
                            await viewModel.renameGroup(group.groupId, to: renameText)
                        }
                    }
                    renameText = ""
                    groupToRename = nil
                }
                .disabled(renameText.trimmingCharacters(in: .whitespaces).isEmpty)
            } message: {
                Text("Enter a new name for this collection.")
            }
            .sheet(item: $selectedGroup) { group in
                GroupDetailView(viewModel: viewModel, group: group)
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Collections", systemImage: "folder.badge.plus")
        } description: {
            Text("Create a collection by selecting files in the library and tapping \"Create Group\".")
        }
    }

    private var groupList: some View {
        List {
            ForEach(viewModel.manualGroups) { group in
                GroupRowView(group: group)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedGroup = group
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            Task {
                                await viewModel.deleteGroup(group.groupId)
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }

                        Button {
                            groupToRename = group
                            renameText = group.displayName
                            showRenameAlert = true
                        } label: {
                            Label("Rename", systemImage: "pencil")
                        }
                        .tint(.orange)
                    }
            }
            .onMove { from, to in
                Task {
                    await moveGroups(from: from, to: to)
                }
            }
        }
        .listStyle(.plain)
    }

    private func moveGroups(from source: IndexSet, to destination: Int) async {
        var orderedIds = viewModel.manualGroups.map(\.groupId)
        orderedIds.move(fromOffsets: source, toOffset: destination)
        await viewModel.reorderGroups(orderedIds)
    }
}

// MARK: - Group Row View

private struct GroupRowView: View {
    let group: GroupRecord

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "folder.fill")
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 44, height: 44)
                .background(Color.blue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(group.displayName)
                    .font(.headline)

                Text("\(group.memberPaths.count) item\(group.memberPaths.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Group Detail View

struct GroupDetailView: View {
    @Bindable var viewModel: LibraryViewModel
    let group: GroupRecord
    @Environment(\.dismiss) private var dismiss

    @State private var editMode: EditMode = .inactive

    var body: some View {
        NavigationStack {
            Group {
                if groupFiles.isEmpty {
                    emptyState
                } else {
                    fileList
                }
            }
            .navigationTitle(group.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .environment(\.editMode, $editMode)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(editMode.isEditing ? "Done" : "Edit") {
                        withAnimation {
                            editMode = editMode.isEditing ? .inactive : .active
                        }
                    }
                    .disabled(groupFiles.isEmpty)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var groupFiles: [ComicFile] {
        let fileMap = Dictionary(
            uniqueKeysWithValues: viewModel.files.map { ($0.url.path, $0) }
        )
        return group.memberPaths.compactMap { fileMap[$0] }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Files", systemImage: "doc")
        } description: {
            Text("This collection is empty. Files may have been moved or deleted.")
        }
    }

    private var fileList: some View {
        List {
            ForEach(groupFiles) { file in
                FileRowView(file: file, isFavourite: viewModel.isFavourite(file))
            }
            .onDelete { indexSet in
                let pathsToRemove = indexSet.map { groupFiles[$0].url.path }
                Task {
                    await viewModel.removeFilesFromGroup(group.groupId, filePaths: pathsToRemove)
                }
            }
        }
        .listStyle(.plain)
    }
}

#Preview("Group Management") {
    GroupManagementView(viewModel: LibraryViewModel())
}
