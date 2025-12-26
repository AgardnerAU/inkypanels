import Foundation

/// Page layout mode for the reader
enum PageLayout: String, CaseIterable, Identifiable {
    case single = "Single Page"
    case dual = "Dual Page"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .single: return "doc"
        case .dual: return "doc.on.doc"
        }
    }

    var description: String {
        switch self {
        case .single: return "Show one page at a time"
        case .dual: return "Show two pages side by side"
        }
    }

    /// Default layout for portrait orientation
    static let portraitDefault: PageLayout = .single

    /// Default layout for landscape orientation
    static let landscapeDefault: PageLayout = .dual
}

/// Reading direction for page ordering
enum ReadingDirection: String, CaseIterable, Identifiable {
    case leftToRight = "Left to Right"
    case rightToLeft = "Right to Left"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .leftToRight: return "arrow.right"
        case .rightToLeft: return "arrow.left"
        }
    }

    var description: String {
        switch self {
        case .leftToRight: return "Western comics (page 1 on left)"
        case .rightToLeft: return "Manga style (page 1 on right)"
        }
    }
}

/// Reader settings stored in UserDefaults
@MainActor
@Observable
final class ReaderSettings {
    static let shared = ReaderSettings()

    // MARK: - Settings

    /// Page layout for portrait orientation
    var portraitLayout: PageLayout {
        didSet { save(portraitLayout.rawValue, for: .portraitLayout) }
    }

    /// Page layout for landscape orientation
    var landscapeLayout: PageLayout {
        didSet { save(landscapeLayout.rawValue, for: .landscapeLayout) }
    }

    /// Current orientation state (not persisted)
    var isLandscape: Bool = false

    /// Current effective layout based on orientation
    var currentLayout: PageLayout {
        isLandscape ? landscapeLayout : portraitLayout
    }

    /// Reading direction
    var readingDirection: ReadingDirection {
        didSet { save(readingDirection.rawValue, for: .readingDirection) }
    }

    /// Whether to show a gap between pages in dual view
    var showPageGap: Bool {
        didSet { save(showPageGap, for: .showPageGap) }
    }

    /// Whether to automatically detect wide spreads and show them as single pages
    var smartSpreadDetection: Bool {
        didSet { save(smartSpreadDetection, for: .smartSpreadDetection) }
    }

    // MARK: - Keys

    private enum Keys: String {
        case portraitLayout = "reader.portraitLayout"
        case landscapeLayout = "reader.landscapeLayout"
        case readingDirection = "reader.readingDirection"
        case showPageGap = "reader.showPageGap"
        case smartSpreadDetection = "reader.smartSpreadDetection"
    }

    // MARK: - Init

    private init() {
        let defaults = UserDefaults.standard

        // Load portrait layout (default: single page)
        if let rawValue = defaults.string(forKey: Keys.portraitLayout.rawValue),
           let layout = PageLayout(rawValue: rawValue) {
            self.portraitLayout = layout
        } else {
            self.portraitLayout = PageLayout.portraitDefault
        }

        // Load landscape layout (default: dual page)
        if let rawValue = defaults.string(forKey: Keys.landscapeLayout.rawValue),
           let layout = PageLayout(rawValue: rawValue) {
            self.landscapeLayout = layout
        } else {
            self.landscapeLayout = PageLayout.landscapeDefault
        }

        // Load reading direction
        if let rawValue = defaults.string(forKey: Keys.readingDirection.rawValue),
           let direction = ReadingDirection(rawValue: rawValue) {
            self.readingDirection = direction
        } else {
            self.readingDirection = .leftToRight
        }

        // Load page gap setting
        if defaults.object(forKey: Keys.showPageGap.rawValue) != nil {
            self.showPageGap = defaults.bool(forKey: Keys.showPageGap.rawValue)
        } else {
            self.showPageGap = true
        }

        // Load smart spread detection
        if defaults.object(forKey: Keys.smartSpreadDetection.rawValue) != nil {
            self.smartSpreadDetection = defaults.bool(forKey: Keys.smartSpreadDetection.rawValue)
        } else {
            self.smartSpreadDetection = true
        }
    }

    // MARK: - Public Methods

    /// Set the layout for the current orientation
    func setCurrentLayout(_ layout: PageLayout) {
        if isLandscape {
            landscapeLayout = layout
        } else {
            portraitLayout = layout
        }
    }

    // MARK: - Persistence

    private func save(_ value: String, for key: Keys) {
        UserDefaults.standard.set(value, forKey: key.rawValue)
    }

    private func save(_ value: Bool, for key: Keys) {
        UserDefaults.standard.set(value, forKey: key.rawValue)
    }
}
