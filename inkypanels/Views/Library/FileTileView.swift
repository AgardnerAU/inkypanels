import SwiftUI

/// A tile view for displaying a comic file in grid layout
struct FileTileView: View {
    let file: ComicFile
    let tileSize: TileSize
    var isFavourite: Bool = false

    private var librarySettings: LibrarySettings { LibrarySettings.shared }

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

            // Metadata (page count and file size)
            if showMetadata {
                metadataView
            }
        }
        .frame(width: tileSize.minColumnWidth)
    }

    /// Whether to show any metadata
    private var showMetadata: Bool {
        file.fileType != .folder && (showPageCountInfo || showFileSizeInfo)
    }

    /// Whether to show page count (setting enabled and page count available)
    private var showPageCountInfo: Bool {
        librarySettings.showPageCount && file.pageCount != nil
    }

    /// Whether to show file size (setting enabled)
    private var showFileSizeInfo: Bool {
        librarySettings.showFileSize
    }

    @ViewBuilder
    private var metadataView: some View {
        HStack(spacing: 4) {
            if showPageCountInfo, let pageCount = file.pageCount {
                Text("\(pageCount)p")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if showPageCountInfo && showFileSizeInfo {
                Text("•")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            if showFileSizeInfo {
                Text(formattedFileSize)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var formattedFileSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: file.fileSize)
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
