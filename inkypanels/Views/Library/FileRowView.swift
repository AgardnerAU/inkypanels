import SwiftUI

struct FileRowView: View {
    let file: ComicFile
    var isFavourite: Bool = false

    private let thumbnailSize = CGSize(width: 50, height: 70)

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail (or folder icon for folders)
            if file.fileType == .folder {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: thumbnailSize.width, height: thumbnailSize.height)
                    .overlay {
                        Image(systemName: "folder.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
            } else {
                ThumbnailView(file: file, size: thumbnailSize)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    if isFavourite {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                    }

                    Text(file.name)
                        .font(.headline)
                        .lineLimit(2)
                }

                HStack(spacing: 8) {
                    Text(file.fileType.rawValue.uppercased())
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(4)

                    Text(formattedFileSize)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let pageCount = file.pageCount {
                        Text("\(pageCount) pages")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let progress = file.readingProgress, progress.hasStarted {
                    ProgressView(value: progress.percentComplete, total: 100)
                        .tint(progress.isCompleted ? .green : .blue)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private var formattedFileSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: file.fileSize)
    }
}

#Preview {
    List {
        FileRowView(file: ComicFile(
            url: URL(fileURLWithPath: "/test.cbz"),
            name: "Batman: The Long Halloween",
            fileType: .cbz,
            fileSize: 52_428_800,
            modifiedDate: Date(),
            pageCount: 384
        ))

        FileRowView(
            file: ComicFile(
                url: URL(fileURLWithPath: "/test2.cbr"),
                name: "Spider-Man: Kraven's Last Hunt",
                fileType: .cbr,
                fileSize: 28_311_552,
                modifiedDate: Date(),
                pageCount: 156,
                readingProgress: ReadingProgress(
                    comicId: UUID(),
                    currentPage: 78,
                    totalPages: 156
                )
            ),
            isFavourite: true
        )

        FileRowView(file: ComicFile(
            url: URL(fileURLWithPath: "/Comics"),
            name: "My Comics Folder",
            fileType: .folder,
            fileSize: 0,
            modifiedDate: Date()
        ))
    }
}
