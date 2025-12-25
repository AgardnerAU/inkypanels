import SwiftUI

struct ContentView: View {
    @State private var selectedTab: Tab? = .library

    enum Tab: String, CaseIterable, Hashable {
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

    var body: some View {
        NavigationSplitView {
            List {
                ForEach(Tab.allCases, id: \.self) { tab in
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
    }
}

// MARK: - Placeholder Views

struct RecentFilesView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "No Recent Files",
                systemImage: "clock",
                description: Text("Comics you open will appear here")
            )
            .navigationTitle("Recent")
        }
    }
}

struct VaultView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Vault Locked",
                systemImage: "lock.fill",
                description: Text("Secure storage coming in v0.4")
            )
            .navigationTitle("Vault")
        }
    }
}

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            Form {
                Section("Reading") {
                    Text("Settings coming soon")
                        .foregroundStyle(.secondary)
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
