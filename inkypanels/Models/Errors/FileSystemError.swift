import Foundation

/// Errors related to file system operations
enum FileSystemError: Error, LocalizedError {
    case fileNotFound(URL)
    case permissionDenied(URL)
    case insufficientStorage
    case deletionFailed(underlying: Error)
    case moveFailed(underlying: Error)
    case copyFailed(underlying: Error)
    case directoryCreationFailed(underlying: Error)
    case invalidPath(String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let url):
            return "File not found: \(url.lastPathComponent)"
        case .permissionDenied(let url):
            return "Permission denied: \(url.lastPathComponent)"
        case .insufficientStorage:
            return "Not enough storage space available"
        case .deletionFailed(let error):
            return "Failed to delete file: \(error.localizedDescription)"
        case .moveFailed(let error):
            return "Failed to move file: \(error.localizedDescription)"
        case .copyFailed(let error):
            return "Failed to copy file: \(error.localizedDescription)"
        case .directoryCreationFailed(let error):
            return "Failed to create directory: \(error.localizedDescription)"
        case .invalidPath(let path):
            return "Invalid file path: \(path)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .fileNotFound:
            return "The file may have been moved or deleted."
        case .permissionDenied:
            return "Check that the app has permission to access this location."
        case .insufficientStorage:
            return "Free up some space on your device and try again."
        case .deletionFailed:
            return "Try closing the file if it's open elsewhere."
        case .moveFailed:
            return "Ensure the destination is accessible and has enough space."
        case .copyFailed:
            return "Ensure the destination is accessible and has enough space."
        case .directoryCreationFailed:
            return "Check available storage and permissions."
        case .invalidPath:
            return "Check that the file path is correct."
        }
    }
}
