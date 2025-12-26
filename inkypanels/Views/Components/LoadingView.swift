import SwiftUI

struct LoadingView: View {
    let message: String
    let progress: Double?

    init(_ message: String = "Loading...", progress: Double? = nil) {
        self.message = message
        self.progress = progress
    }

    var body: some View {
        VStack(spacing: 16) {
            if let progress {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .frame(width: 200)
            } else {
                ProgressView()
                    .scaleEffect(1.5)
            }

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview("Indeterminate") {
    LoadingView("Loading comic...")
}

#Preview("With Progress") {
    LoadingView("Extracting pages...", progress: 0.6)
}
