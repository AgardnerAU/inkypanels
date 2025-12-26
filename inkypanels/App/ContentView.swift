import SwiftData
import SwiftUI

struct ContentView: View {
    @AppStorage(Constants.UserDefaultsKey.showRecentFiles) private var showRecentFiles = true
    @State private var selectedTab: Tab? = .library
    @Environment(AppState.self) private var appState: AppState?
    @State private var showOpenedFileReader = false
    @State private var openedComic: ComicFile?

    enum Tab: String, Hashable {
        case library = "Library"
        case recent = "Recent"
        case vault = "Vault"
        case settings = "Settings"

        var icon: String {
            switch self {
            case .library: return "books.vertical"
            case .recent: return "clock"
            case .vault: return "lock.fill"
            case .settings: return "gear"
            }
        }
    }

    private var visibleTabs: [Tab] {
        var tabs: [Tab] = [.library]
        if showRecentFiles {
            tabs.append(.recent)
        }
        tabs.append(contentsOf: [.vault, .settings])
        return tabs
    }

    var body: some View {
        NavigationSplitView {
            List {
                ForEach(visibleTabs, id: \.self) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        Label(tab.rawValue, systemImage: tab.icon)
                    }
                    .listRowBackground(selectedTab == tab ? Color.accentColor.opacity(0.2) : nil)
                }
            }
            .navigationTitle("inkypanels")
        } detail: {
            switch selectedTab {
            case .library:
                LibraryView()
            case .recent:
                RecentFilesView()
            case .vault:
                VaultView()
            case .settings:
                SettingsView()
            case .none:
                LibraryView()
            }
        }
        .onChange(of: showRecentFiles) { _, newValue in
            // If Recent tab is hidden and currently selected, switch to Library
            if !newValue && selectedTab == .recent {
                selectedTab = .library
            }
        }
        .onChange(of: appState?.fileToOpen) { _, newFile in
            // Handle file opened from external source (Files app, Share sheet, etc.)
            if let comic = newFile {
                openedComic = comic
                showOpenedFileReader = true
                // Clear the trigger
                appState?.fileToOpen = nil
            }
        }
        .fullScreenCover(isPresented: $showOpenedFileReader) {
            // Clean up security-scoped resource when dismissed
            if let url = appState?.openedFileURL {
                url.stopAccessingSecurityScopedResource()
                appState?.openedFileURL = nil
            }
        } content: {
            if let comic = openedComic {
                NavigationStack {
                    ReaderView(comic: comic)
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button("Done") {
                                    showOpenedFileReader = false
                                }
                            }
                        }
                }
            }
        }
    }
}

// MARK: - Recent Files View

struct RecentFilesView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = RecentFilesViewModel()
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if viewModel.isLoading {
                    LoadingView("Loading recent files...")
                } else if viewModel.recentFiles.isEmpty {
                    ContentUnavailableView(
                        "No Recent Files",
                        systemImage: "clock",
                        description: Text("Comics you open will appear here")
                    )
                } else {
                    recentFilesList
                }
            }
            .navigationTitle("Recent")
            .navigationDestination(for: ComicFile.self) { file in
                ReaderView(comic: file)
            }
            .refreshable {
                await viewModel.loadRecentFiles()
            }
        }
        .task {
            viewModel.configureService(modelContext: modelContext)
            await viewModel.loadRecentFiles()
        }
    }

    private var recentFilesList: some View {
        List {
            ForEach(viewModel.recentFiles, id: \.file.id) { item in
                NavigationLink(value: item.file) {
                    RecentFileRowView(file: item.file, progress: item.progress)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        Task { await viewModel.clearRecent(item.progress) }
                    } label: {
                        Label("Remove", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
    }
}

struct RecentFileRowView: View {
    let file: ComicFile
    let progress: ProgressRecord

    private let thumbnailSize = CGSize(width: 60, height: 80)

    var body: some View {
        HStack(spacing: 12) {
            ThumbnailView(file: file, size: thumbnailSize)
                .clipShape(RoundedRectangle(cornerRadius: 4))

            VStack(alignment: .leading, spacing: 4) {
                Text(file.name)
                    .font(.headline)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    // Progress indicator
                    Text("\(progress.currentPage + 1) of \(progress.totalPages)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if progress.isCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                    }
                }

                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.secondary.opacity(0.2))

                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.accentColor)
                            .frame(width: geometry.size.width * (progress.percentComplete / 100))
                    }
                }
                .frame(height: 4)

                // Last read date
                Text(progress.lastReadDate, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @AppStorage(Constants.UserDefaultsKey.showRecentFiles) private var showRecentFiles = true
    @AppStorage(Constants.UserDefaultsKey.hideVaultFromRecent) private var hideVaultFromRecent = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Show Recent Files Tab", isOn: $showRecentFiles)
                    Toggle("Hide Vault Files from Recent", isOn: $hideVaultFromRecent)
                } header: {
                    Text("Recent Files")
                } footer: {
                    Text("When enabled, files from the vault will not appear in the Recent tab.")
                }

                Section("About") {
                    LabeledContent("Version", value: Constants.App.version)
                    LabeledContent("App", value: Constants.App.name)
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    ContentView()
}
