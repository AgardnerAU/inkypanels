import SwiftUI

struct ThumbnailView: View {
    let file: ComicFile
    let size: CGSize

    @State private var thumbnailData: Data?
    @State private var isLoading: Bool = true

    /// Shared thumbnail service instance
    private static let thumbnailService = ThumbnailService()

    var body: some View {
        Group {
            if let thumbnailData,
               let uiImage = UIImage(data: thumbnailData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size.width, height: size.height)
                    .clipped()
            } else if isLoading {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.1))
                    .frame(width: size.width, height: size.height)
                    .overlay {
                        ProgressView()
                    }
            } else {
                // Placeholder for failed loads
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: size.width, height: size.height)
                    .overlay {
                        Image(systemName: file.fileType.icon)
                            .font(.title)
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .cornerRadius(4)
        .task(priority: .userInitiated) {
            await loadThumbnail()
        }
    }

    private func loadThumbnail() async {
        do {
            thumbnailData = try await Self.thumbnailService.thumbnail(for: file)
        } catch {
            // Silently fail - placeholder will show
        }
        isLoading = false
    }

    /// Access to shared service for background generation
    static func generateThumbnailsInBackground(for files: [ComicFile]) {
        Task {
            await thumbnailService.generateInBackground(files: files)
        }
    }
}

#Preview {
    ThumbnailView(
        file: ComicFile(
            url: URL(fileURLWithPath: "/test.cbz"),
            name: "Test",
            fileType: .cbz,
            fileSize: 1000,
            modifiedDate: Date()
        ),
        size: CGSize(width: 100, height: 140)
    )
}
