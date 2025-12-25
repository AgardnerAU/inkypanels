import Foundation

/// Top-level error type for the application
enum InkyPanelsError: Error, LocalizedError {
    case archive(ArchiveError)
    case vault(VaultError)
    case fileSystem(FileSystemError)
    case reader(ReaderError)

    var errorDescription: String? {
        switch self {
        case .archive(let error):
            return error.errorDescription
        case .vault(let error):
            return error.errorDescription
        case .fileSystem(let error):
            return error.errorDescription
        case .reader(let error):
            return error.errorDescription
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .archive(let error):
            return error.recoverySuggestion
        case .vault(let error):
            return error.recoverySuggestion
        case .fileSystem(let error):
            return error.recoverySuggestion
        case .reader(let error):
            return error.recoverySuggestion
        }
    }
}
