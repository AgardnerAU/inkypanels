import Foundation

/// Page layout mode for the reader
enum PageLayout: String, CaseIterable, Identifiable {
    case single = "Single Page"
    case dual = "Dual Page"
    case auto = "Auto"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .single: return "doc"
        case .dual: return "doc.on.doc"
        case .auto: return "sparkles.rectangle.stack"
        }
    }

    var description: String {
        switch self {
        case .single: return "Always show one page"
        case .dual: return "Always show two pages side by side"
        case .auto: return "Single in portrait, dual in landscape"
        }
    }
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

    /// Page layout mode
    var pageLayout: PageLayout {
        didSet { save(pageLayout.rawValue, for: .pageLayout) }
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
        case pageLayout = "reader.pageLayout"
        case readingDirection = "reader.readingDirection"
        case showPageGap = "reader.showPageGap"
        case smartSpreadDetection = "reader.smartSpreadDetection"
    }

    // MARK: - Init

    private init() {
        let defaults = UserDefaults.standard

        // Load page layout
        if let rawValue = defaults.string(forKey: Keys.pageLayout.rawValue),
           let layout = PageLayout(rawValue: rawValue) {
            self.pageLayout = layout
        } else {
            self.pageLayout = .auto
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

    // MARK: - Persistence

    private func save(_ value: String, for key: Keys) {
        UserDefaults.standard.set(value, forKey: key.rawValue)
    }

    private func save(_ value: Bool, for key: Keys) {
        UserDefaults.standard.set(value, forKey: key.rawValue)
    }
}
