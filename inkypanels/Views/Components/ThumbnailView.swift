import SwiftUI

struct ThumbnailView: View {
    let file: ComicFile
    let size: CGSize

    @State private var thumbnailData: Data?
    @State private var isLoading: Bool = true

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
                ProgressView()
                    .frame(width: size.width, height: size.height)
                    .background(Color.secondary.opacity(0.1))
            } else {
                // Placeholder
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: size.width, height: size.height)
                    .overlay {
                        Image(systemName: "book.closed")
                            .font(.title)
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .cornerRadius(4)
        .task {
            await loadThumbnail()
        }
    }

    private func loadThumbnail() async {
        // TODO: Load from ThumbnailService
        isLoading = false
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
