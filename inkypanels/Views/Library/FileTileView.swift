import SwiftUI

/// A tile view for displaying a comic file in grid layout
struct FileTileView: View {
    let file: ComicFile
    let tileSize: TileSize
    var isFavourite: Bool = false

    var body: some View {
        VStack(spacing: 8) {
            // Thumbnail or folder icon
            ZStack(alignment: .topTrailing) {
                if file.fileType == .folder {
                    folderThumbnail
                } else {
                    ThumbnailView(file: file, size: tileSize.thumbnailSize)
                }

                // Favourite indicator
                if isFavourite {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                        .padding(4)
                        .background(.ultraThinMaterial, in: Circle())
                        .padding(4)
                }

                // Reading progress overlay
                if let progress = file.readingProgress, progress.hasStarted {
                    VStack {
                        Spacer()
                        ProgressView(value: progress.percentComplete, total: 100)
                            .tint(progress.isCompleted ? .green : .blue)
                            .background(Color.black.opacity(0.3))
                    }
                    .frame(width: tileSize.thumbnailSize.width, height: tileSize.thumbnailSize.height)
                }
            }

            // Title
            Text(file.name)
                .font(.caption)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: tileSize.thumbnailSize.width)
        }
        .frame(width: tileSize.minColumnWidth)
    }

    private var folderThumbnail: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color.secondary.opacity(0.2))
            .frame(width: tileSize.thumbnailSize.width, height: tileSize.thumbnailSize.height)
            .overlay {
                Image(systemName: "folder.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
            }
    }
}

#Preview {
    LazyVGrid(columns: [GridItem(.adaptive(minimum: 160))], spacing: 16) {
        FileTileView(
            file: ComicFile(
                url: URL(fileURLWithPath: "/test.cbz"),
                name: "Batman: The Long Halloween",
                fileType: .cbz,
                fileSize: 52_428_800,
                modifiedDate: Date()
            ),
            tileSize: .medium
        )

        FileTileView(
            file: ComicFile(
                url: URL(fileURLWithPath: "/test2.cbr"),
                name: "Spider-Man",
                fileType: .cbr,
                fileSize: 28_311_552,
                modifiedDate: Date(),
                readingProgress: ReadingProgress(
                    comicId: UUID(),
                    currentPage: 78,
                    totalPages: 156
                )
            ),
            tileSize: .medium,
            isFavourite: true
        )

        FileTileView(
            file: ComicFile(
                url: URL(fileURLWithPath: "/folder"),
                name: "My Comics Folder",
                fileType: .folder,
                fileSize: 0,
                modifiedDate: Date()
            ),
            tileSize: .medium
        )
    }
    .padding()
}
