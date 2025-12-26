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
        return nil
    }

    private var systemImage: String {
        if let inkyError = error as? InkyPanelsError {
            switch inkyError {
            case .archive(.rar5NotSupported):
                return "doc.badge.gearshape"
            default:
                return "exclamationmark.triangle"
            }
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
