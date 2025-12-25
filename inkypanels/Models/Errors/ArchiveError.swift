import Foundation

/// Errors related to archive extraction and handling
enum ArchiveError: Error, LocalizedError {
    case unsupportedFormat(String)
    case rar5NotSupported
    case corruptedArchive
    case extractionFailed(underlying: Error)
    case passwordProtected
    case emptyArchive
    case fileNotFound(String)
    case invalidArchive

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat(let format):
            return "Unsupported archive format: \(format)"
        case .rar5NotSupported:
            return "RAR5 format is not supported"
        case .corruptedArchive:
            return "The archive appears to be corrupted"
        case .extractionFailed(let error):
            return "Failed to extract archive: \(error.localizedDescription)"
        case .passwordProtected:
            return "This archive is password protected"
        case .emptyArchive:
            return "The archive contains no readable images"
        case .fileNotFound(let name):
            return "File not found in archive: \(name)"
        case .invalidArchive:
            return "The file is not a valid archive"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .unsupportedFormat:
            return "Try converting the file to CBZ format."
        case .rar5NotSupported:
            return "This comic uses RAR5 format which isn't currently supported. Please convert to CBZ format for best compatibility."
        case .corruptedArchive:
            return "Try re-downloading the file or use a different source."
        case .extractionFailed:
            return "Try opening a different file or restarting the app."
        case .passwordProtected:
            return "Password-protected archives are not supported."
        case .emptyArchive:
            return "The archive may only contain unsupported file types."
        case .fileNotFound:
            return "The archive may be corrupted or incomplete."
        case .invalidArchive:
            return "Ensure the file is a valid comic archive (CBZ, CBR, CB7)."
        }
    }
}
