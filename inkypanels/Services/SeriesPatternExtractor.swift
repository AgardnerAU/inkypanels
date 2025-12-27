import Foundation

/// Extracts series patterns from filenames to enable automatic grouping
enum SeriesPatternExtractor {

    // MARK: - Cached Regex Patterns

    // swiftlint:disable:next line_length
    private static let volumeRegex = try? NSRegularExpression(pattern: #"^(.+?)\s*(?:Vol\.?|Volume|v)\s*(\d+).*$"#, options: .caseInsensitive)
    private static let issueRegex = try? NSRegularExpression(pattern: #"^(.+?)\s*(?:#|Issue\s*)(\d+).*$"#, options: .caseInsensitive)
    private static let chapterRegex = try? NSRegularExpression(pattern: #"^(.+?)\s*(?:Chapter|Ch\.?)\s*(\d+).*$"#, options: .caseInsensitive)
    private static let numberSuffixRegex = try? NSRegularExpression(pattern: #"^(.+?)[\s\-_\.]+(\d{2,})$"#, options: [])
    private static let yearNumberRegex = try? NSRegularExpression(pattern: #"^(.+?\s*\(\d{4}\))\s*(\d+).*$"#, options: [])
    private static let parenNumberRegex = try? NSRegularExpression(pattern: #"^(.+?)\s*\((\d+)\)$"#, options: [])

    // MARK: - Pattern Extraction

    /// Extract a series pattern from a filename
    /// - Parameter filename: The filename (without extension) to analyze
    /// - Returns: A SeriesPattern if a pattern was detected, nil otherwise
    static func extractPattern(from filename: String) -> SeriesPattern? {
        let name = filename.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return nil }

        // Try each pattern in order of specificity
        if let pattern = tryVolumePattern(name) { return pattern }
        if let pattern = tryIssuePattern(name) { return pattern }
        if let pattern = tryChapterPattern(name) { return pattern }
        if let pattern = tryNumberSuffixPattern(name) { return pattern }
        if let pattern = tryParenthesizedNumberPattern(name) { return pattern }

        return nil
    }

    // MARK: - Pattern Matchers

    /// Matches: "Name Vol. 1", "Name Vol 1", "Name Volume 1", "Name v1"
    private static func tryVolumePattern(_ name: String) -> SeriesPattern? {
        guard let regex = volumeRegex,
              let match = regex.firstMatch(
                  in: name,
                  options: [],
                  range: NSRange(name.startIndex..., in: name)
              ),
              let baseRange = Range(match.range(at: 1), in: name),
              let numberRange = Range(match.range(at: 2), in: name),
              let number = Int(String(name[numberRange])) else {
            return nil
        }

        let baseName = String(name[baseRange]).trimmingCharacters(in: .whitespaces)
        guard !baseName.isEmpty else { return nil }

        return SeriesPattern(
            baseName: baseName,
            volumeIndicator: "Vol.",
            volumeNumber: number,
            originalName: name
        )
    }

    /// Matches: "Name #1", "Name #001", "Name Issue 1"
    private static func tryIssuePattern(_ name: String) -> SeriesPattern? {
        guard let regex = issueRegex,
              let match = regex.firstMatch(
                  in: name,
                  options: [],
                  range: NSRange(name.startIndex..., in: name)
              ),
              let baseRange = Range(match.range(at: 1), in: name),
              let numberRange = Range(match.range(at: 2), in: name),
              let number = Int(String(name[numberRange])) else {
            return nil
        }

        let baseName = String(name[baseRange]).trimmingCharacters(in: .whitespaces)
        guard !baseName.isEmpty else { return nil }

        return SeriesPattern(
            baseName: baseName,
            volumeIndicator: "#",
            volumeNumber: number,
            originalName: name
        )
    }

    /// Matches: "Name Chapter 1", "Name Ch. 1", "Name Ch1"
    private static func tryChapterPattern(_ name: String) -> SeriesPattern? {
        guard let regex = chapterRegex,
              let match = regex.firstMatch(
                  in: name,
                  options: [],
                  range: NSRange(name.startIndex..., in: name)
              ),
              let baseRange = Range(match.range(at: 1), in: name),
              let numberRange = Range(match.range(at: 2), in: name),
              let number = Int(String(name[numberRange])) else {
            return nil
        }

        let baseName = String(name[baseRange]).trimmingCharacters(in: .whitespaces)
        guard !baseName.isEmpty else { return nil }

        return SeriesPattern(
            baseName: baseName,
            volumeIndicator: "Chapter",
            volumeNumber: number,
            originalName: name
        )
    }

    /// Matches: "Name 01", "Name 001", "Name - 01"
    /// Only matches if there's a clear separator before the number
    private static func tryNumberSuffixPattern(_ name: String) -> SeriesPattern? {
        guard let regex = numberSuffixRegex,
              let match = regex.firstMatch(
                  in: name,
                  options: [],
                  range: NSRange(name.startIndex..., in: name)
              ),
              let baseRange = Range(match.range(at: 1), in: name),
              let numberRange = Range(match.range(at: 2), in: name),
              let number = Int(String(name[numberRange])) else {
            return nil
        }

        let baseName = String(name[baseRange]).trimmingCharacters(in: .whitespaces)
        guard !baseName.isEmpty else { return nil }

        return SeriesPattern(
            baseName: baseName,
            volumeIndicator: nil,
            volumeNumber: number,
            originalName: name
        )
    }

    /// Matches: "Name (1)", "Name (01)", "Name (2022) 01"
    /// Handles year in parentheses followed by number
    private static func tryParenthesizedNumberPattern(_ name: String) -> SeriesPattern? {
        // First try: "Name (year) number" pattern
        if let regex = yearNumberRegex,
           let match = regex.firstMatch(
               in: name,
               options: [],
               range: NSRange(name.startIndex..., in: name)
           ),
           let baseRange = Range(match.range(at: 1), in: name),
           let numberRange = Range(match.range(at: 2), in: name),
           let number = Int(String(name[numberRange])) {

            let baseName = String(name[baseRange]).trimmingCharacters(in: .whitespaces)
            if !baseName.isEmpty {
                return SeriesPattern(
                    baseName: baseName,
                    volumeIndicator: nil,
                    volumeNumber: number,
                    originalName: name
                )
            }
        }

        // Second try: "Name (number)" pattern
        guard let regex = parenNumberRegex,
              let match = regex.firstMatch(
                  in: name,
                  options: [],
                  range: NSRange(name.startIndex..., in: name)
              ),
              let baseRange = Range(match.range(at: 1), in: name),
              let numberRange = Range(match.range(at: 2), in: name),
              let number = Int(String(name[numberRange])) else {
            return nil
        }

        let baseName = String(name[baseRange]).trimmingCharacters(in: .whitespaces)
        guard !baseName.isEmpty else { return nil }

        return SeriesPattern(
            baseName: baseName,
            volumeIndicator: nil,
            volumeNumber: number,
            originalName: name
        )
    }

    // MARK: - Grouping

    /// Group files by their extracted series patterns
    /// - Parameters:
    ///   - files: The files to group
    ///   - minimumGroupSize: Minimum number of files required to form a group (default: 2)
    /// - Returns: Array of DisplayGroups for files that match patterns, sorted by name
    static func groupFiles(
        _ files: [ComicFile],
        minimumGroupSize: Int = 2
    ) -> [DisplayGroup] {
        // Extract patterns for each file
        var patternMap: [String: [(file: ComicFile, pattern: SeriesPattern)]] = [:]

        for file in files {
            // Use name without extension for pattern matching
            let filename = file.name
            if let pattern = extractPattern(from: filename) {
                let key = pattern.groupKey
                patternMap[key, default: []].append((file, pattern))
            }
        }

        // Build display groups from patterns meeting minimum size
        var groups: [DisplayGroup] = []

        for (key, items) in patternMap where items.count >= minimumGroupSize {
            // Sort files by volume number, then by name
            let sortedItems = items.sorted { lhs, rhs in
                if let lhsNum = lhs.pattern.volumeNumber,
                   let rhsNum = rhs.pattern.volumeNumber {
                    return lhsNum < rhsNum
                }
                return lhs.file.name.localizedCaseInsensitiveCompare(rhs.file.name) == .orderedAscending
            }

            // Use the first item's base name for display (preserves original casing)
            let displayName = sortedItems.first?.pattern.baseName ?? key

            let group = DisplayGroup(
                id: "auto-\(key)",
                name: displayName,
                files: sortedItems.map(\.file),
                isAutomatic: true,
                pattern: key
            )
            groups.append(group)
        }

        // Sort groups alphabetically by name
        return groups.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    /// Get files that don't belong to any auto-detected group
    /// - Parameters:
    ///   - files: All files to check
    ///   - groups: The auto-detected groups
    /// - Returns: Files that aren't in any group
    static func ungroupedFiles(
        from files: [ComicFile],
        excludingGroups groups: [DisplayGroup]
    ) -> [ComicFile] {
        let groupedFileIds = Set(groups.flatMap { $0.files.map(\.id) })
        return files.filter { !groupedFileIds.contains($0.id) }
    }
}
