import SwiftUI

struct ErrorView: View {
    let error: Error
    let retryAction: (() -> Void)?

    init(_ error: Error, retryAction: (() -> Void)? = nil) {
        self.error = error
        self.retryAction = retryAction
    }

    private var recoverySuggestion: String? {
        if let inkyError = error as? InkyPanelsError {
            return inkyError.recoverySuggestion
        }
        if let archiveError = error as? ArchiveError {
            return archiveError.recoverySuggestion
        }
        if let vaultError = error as? VaultError {
            return vaultError.recoverySuggestion
        }
        if let readerError = error as? ReaderError {
            return readerError.recoverySuggestion
        }
        if let fileSystemError = error as? FileSystemError {
            return fileSystemError.recoverySuggestion
        }
        return nil
    }

    private var systemImage: String {
        if let inkyError = error as? InkyPanelsError {
            switch inkyError {
            case .archive(.rar5NotSupported):
                return "doc.badge.gearshape"
            case .vault:
                return "lock.trianglebadge.exclamationmark"
            case .fileSystem(.permissionDenied):
                return "lock.shield"
            case .fileSystem(.insufficientStorage):
                return "externaldrive.badge.xmark"
            default:
                return "exclamationmark.triangle"
            }
        }
        if error is VaultError {
            return "lock.trianglebadge.exclamationmark"
        }
        if error is FileSystemError {
            return "folder.badge.questionmark"
        }
        if error is ArchiveError {
            return "doc.zipper"
        }
        if error is ReaderError {
            return "photo.badge.exclamationmark"
        }
        return "exclamationmark.triangle"
    }

    var body: some View {
        ContentUnavailableView {
            Label("Error", systemImage: systemImage)
        } description: {
            VStack(spacing: 8) {
                Text(error.localizedDescription)

                if let suggestion = recoverySuggestion {
                    Text(suggestion)
                        .foregroundStyle(.secondary)
                        .font(.footnote)
                }
            }
        } actions: {
            if let retryAction {
                Button("Try Again", action: retryAction)
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}

#Preview {
    ErrorView(ReaderError.noPages) {
        print("Retry tapped")
    }
}
