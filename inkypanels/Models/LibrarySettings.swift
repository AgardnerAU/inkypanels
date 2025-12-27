import Foundation
import CoreGraphics

/// View mode for the library display
enum LibraryViewMode: String, CaseIterable, Identifiable {
    case list = "List"
    case grid = "Grid"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .list: return "list.bullet"
        case .grid: return "square.grid.2x2"
        }
    }
}

/// Tile size options for grid view
enum TileSize: String, CaseIterable, Identifiable {
    case small = "Small"
    case medium = "Medium"
    case large = "Large"

    var id: String { rawValue }

    /// The size of the thumbnail in grid view
    var thumbnailSize: CGSize {
        switch self {
        case .small: return CGSize(width: 100, height: 140)
        case .medium: return CGSize(width: 140, height: 196)
        case .large: return CGSize(width: 180, height: 252)
        }
    }

    /// Minimum width for grid columns
    var minColumnWidth: CGFloat {
        switch self {
        case .small: return 120
        case .medium: return 160
        case .large: return 200
        }
    }
}

/// Library display settings stored in UserDefaults
@MainActor
@Observable
final class LibrarySettings {
    static let shared = LibrarySettings()

    // MARK: - Settings

    /// Current view mode (list or grid)
    var viewMode: LibraryViewMode {
        didSet { save(viewMode.rawValue, for: .viewMode) }
    }

    /// Tile size for grid view
    var tileSize: TileSize {
        didSet { save(tileSize.rawValue, for: .tileSize) }
    }

    /// Whether to show page count for files
    var showPageCount: Bool {
        didSet { saveBool(showPageCount, for: .showPageCount) }
    }

    /// Whether to show file size for files
    var showFileSize: Bool {
        didSet { saveBool(showFileSize, for: .showFileSize) }
    }

    // MARK: - Keys

    private enum Keys: String {
        case viewMode = "library.viewMode"
        case tileSize = "library.tileSize"
        case showPageCount = "library.showPageCount"
        case showFileSize = "library.showFileSize"
    }

    // MARK: - Init

    private init() {
        let defaults = UserDefaults.standard

        // Load view mode (default: list)
        if let rawValue = defaults.string(forKey: Keys.viewMode.rawValue),
           let mode = LibraryViewMode(rawValue: rawValue) {
            self.viewMode = mode
        } else {
            self.viewMode = .list
        }

        // Load tile size (default: medium)
        if let rawValue = defaults.string(forKey: Keys.tileSize.rawValue),
           let size = TileSize(rawValue: rawValue) {
            self.tileSize = size
        } else {
            self.tileSize = .medium
        }

        // Load show page count (default: true)
        if defaults.object(forKey: Keys.showPageCount.rawValue) != nil {
            self.showPageCount = defaults.bool(forKey: Keys.showPageCount.rawValue)
        } else {
            self.showPageCount = true
        }

        // Load show file size (default: true)
        if defaults.object(forKey: Keys.showFileSize.rawValue) != nil {
            self.showFileSize = defaults.bool(forKey: Keys.showFileSize.rawValue)
        } else {
            self.showFileSize = true
        }
    }

    // MARK: - Persistence

    private func save(_ value: String, for key: Keys) {
        UserDefaults.standard.set(value, forKey: key.rawValue)
    }

    private func saveBool(_ value: Bool, for key: Keys) {
        UserDefaults.standard.set(value, forKey: key.rawValue)
    }
}
