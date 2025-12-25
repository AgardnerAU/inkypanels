import Foundation

/// Errors related to the comic reader
enum ReaderError: Error, LocalizedError {
    case pageLoadFailed(index: Int)
    case unsupportedImageFormat
    case imageTooLarge
    case noPages
    case invalidPageIndex(Int)
    case imageDecodingFailed

    var errorDescription: String? {
        switch self {
        case .pageLoadFailed(let index):
            return "Failed to load page \(index + 1)"
        case .unsupportedImageFormat:
            return "Unsupported image format"
        case .imageTooLarge:
            return "Image is too large to display"
        case .noPages:
            return "No pages to display"
        case .invalidPageIndex(let index):
            return "Invalid page number: \(index + 1)"
        case .imageDecodingFailed:
            return "Failed to decode image"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .pageLoadFailed:
            return "Try navigating to a different page or reopening the comic."
        case .unsupportedImageFormat:
            return "This image format is not supported. Supported formats: PNG, JPG, WEBP, TIFF, GIF."
        case .imageTooLarge:
            return "The image exceeds the maximum supported size."
        case .noPages:
            return "The comic appears to be empty or corrupted."
        case .invalidPageIndex:
            return "Navigate using the page controls."
        case .imageDecodingFailed:
            return "The image file may be corrupted."
        }
    }
}
