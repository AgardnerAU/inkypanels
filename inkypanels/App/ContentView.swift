import SwiftData
import SwiftUI

struct ContentView: View {
    @AppStorage(Constants.UserDefaultsKey.showRecentFiles) private var showRecentFiles = true
    @AppStorage(Constants.UserDefaultsKey.autoHideSidebar) private var autoHideSidebar = false
    @AppStorage(Constants.UserDefaultsKey.hideVaultFromSidebar) private var hideVaultFromSidebar = false
    @State private var selectedTab: Tab? = .library
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @Environment(AppState.self) private var appState: AppState?
    @State private var showOpenedFileReader = false
    @State private var openedComic: ComicFile?
    @State private var vaultTemporarilyRevealed = false

    enum Tab: String, Hashable {
        case library = "Library"
        case favourites = "Favourites"
        case recent = "Recent"
        case vault = "Vault"
        case settings = "Settings"

        var icon: String {
            switch self {
            case .library: return "books.vertical"
            case .favourites: return "star.fill"
            case .recent: return "clock"
            case .vault: return "lock.fill"
            case .settings: return "gear"
            }
        }
    }

    private var visibleTabs: [Tab] {
        var tabs: [Tab] = [.library, .favourites]
        if showRecentFiles {
            tabs.append(.recent)
        }
        // Only show vault if not hidden, or if temporarily revealed
        if !hideVaultFromSidebar || vaultTemporarilyRevealed {
            tabs.append(.vault)
        }
        tabs.append(.settings)
        return tabs
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
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
            .navigationTitle("Inky Panels Comic Reader")
        } detail: {
            switch selectedTab {
            case .library:
                LibraryView()
            case .favourites:
                FavouritesView()
            case .recent:
                RecentFilesView()
            case .vault:
                VaultView()
            case .settings:
                SettingsView(onRevealVault: {
                    vaultTemporarilyRevealed = true
                })
            case .none:
                LibraryView()
            }
        }
        .navigationSplitViewStyle(.balanced)
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
        .onChange(of: appState?.isViewingFile) { _, isViewing in
            // Auto-hide sidebar when opening a file, show when closing
            if autoHideSidebar {
                columnVisibility = (isViewing == true) ? .detailOnly : .all
            }
        }
        .onChange(of: autoHideSidebar) { _, newValue in
            // When auto-hide is toggled, update visibility based on current state
            if newValue {
                // Only hide if currently viewing a file
                columnVisibility = (appState?.isViewingFile == true) ? .detailOnly : .all
            } else {
                // When disabled, always show sidebar
                columnVisibility = .all
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

// MARK: - Favourites View

struct FavouritesView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = FavouritesViewModel()
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if viewModel.isLoading {
                    LoadingView("Loading favourites...")
                } else if viewModel.favouriteFiles.isEmpty {
                    ContentUnavailableView(
                        "No Favourites",
                        systemImage: "star",
                        description: Text("Swipe right on a comic and tap the star to add it to favourites")
                    )
                } else {
                    favouritesList
                }
            }
            .navigationTitle("Favourites")
            .navigationDestination(for: ComicFile.self) { file in
                ReaderView(comic: file)
            }
            .refreshable {
                await viewModel.loadFavourites()
            }
        }
        .task {
            viewModel.configureService(modelContext: modelContext)
            await viewModel.loadFavourites()
        }
    }

    private var favouritesList: some View {
        List {
            ForEach(viewModel.favouriteFiles) { file in
                NavigationLink(value: file) {
                    FavouriteFileRowView(file: file)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        Task { await viewModel.removeFavourite(file) }
                    } label: {
                        Label("Remove", systemImage: "star.slash")
                    }
                    .tint(.yellow)
                }
            }
        }
        .listStyle(.plain)
    }
}

struct FavouriteFileRowView: View {
    let file: ComicFile

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
                    Text(file.fileType.rawValue.uppercased())
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(4)

                    Text(formattedFileSize)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Image(systemName: "star.fill")
                .foregroundStyle(.yellow)
        }
        .padding(.vertical, 4)
    }

    private var formattedFileSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: file.fileSize)
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @AppStorage(Constants.UserDefaultsKey.showRecentFiles) private var showRecentFiles = true
    @AppStorage(Constants.UserDefaultsKey.hideVaultFromRecent) private var hideVaultFromRecent = false
    @AppStorage(Constants.UserDefaultsKey.autoHideSidebar) private var autoHideSidebar = false
    @AppStorage(Constants.UserDefaultsKey.clearRecentOnExit) private var clearRecentOnExit = false
    @AppStorage(Constants.UserDefaultsKey.hideVaultFromSidebar) private var hideVaultFromSidebar = false

    var onRevealVault: (() -> Void)?

    @State private var tapCount = 0
    @State private var showVaultRevealedMessage = false

    var body: some View {
        NavigationStack {
            Form {
                LibrarySettingsSection()
                sidebarSection
                recentFilesSection
                aboutSection
            }
            .navigationTitle("Settings")
            .alert("Vault Revealed", isPresented: $showVaultRevealedMessage) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("The Vault is now visible in the sidebar.")
            }
        }
    }

    private var sidebarSection: some View {
        Section {
            Toggle("Auto-hide Sidebar", isOn: $autoHideSidebar)
        } header: {
            Text("Sidebar")
        } footer: {
            Text("When enabled, the sidebar hides automatically when reading a file and reappears when you return to the library.")
        }
    }

    private var recentFilesSection: some View {
        Section {
            Toggle("Show Recent Files Tab", isOn: $showRecentFiles)
            Toggle("Hide Vault Files from Recent", isOn: $hideVaultFromRecent)
            Toggle("Clear Recent Files on Exit", isOn: $clearRecentOnExit)
        } header: {
            Text("Recent Files")
        } footer: {
            Text("When 'Clear on Exit' is enabled, your reading history will be automatically cleared when leaving the app.")
        }
    }

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version", value: Constants.App.version)
            appNameRow
        }
    }

    private var appNameRow: some View {
        HStack {
            Text("App")
                .foregroundStyle(.primary)
            Spacer()
            Text(Constants.App.name)
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if hideVaultFromSidebar {
                tapCount += 1
                if tapCount >= 3 {
                    onRevealVault?()
                    showVaultRevealedMessage = true
                    tapCount = 0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    tapCount = 0
                }
            }
        }
    }
}

// MARK: - Library Settings Section

private struct LibrarySettingsSection: View {
    private var librarySettings = LibrarySettings.shared

    var body: some View {
        Section {
            viewModePicker
            tileSizePicker
        } header: {
            Text("Library")
        } footer: {
            Text("Choose how comics are displayed in the library. Tile size only applies to grid view.")
        }
    }

    private var viewModePicker: some View {
        Picker("View Mode", selection: viewModeBinding) {
            ForEach(LibraryViewMode.allCases) { mode in
                Label(mode.rawValue, systemImage: mode.icon)
                    .tag(mode)
            }
        }
    }

    private var tileSizePicker: some View {
        Picker("Tile Size", selection: tileSizeBinding) {
            ForEach(TileSize.allCases) { size in
                Text(size.rawValue).tag(size)
            }
        }
        .disabled(librarySettings.viewMode != .grid)
    }

    private var viewModeBinding: Binding<LibraryViewMode> {
        Binding(
            get: { librarySettings.viewMode },
            set: { librarySettings.viewMode = $0 }
        )
    }

    private var tileSizeBinding: Binding<TileSize> {
        Binding(
            get: { librarySettings.tileSize },
            set: { librarySettings.tileSize = $0 }
        )
    }
}

#Preview {
    ContentView()
}
