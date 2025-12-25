import SwiftUI

struct FileRowView: View {
    let file: ComicFile

    var body: some View {
        NavigationLink(value: file) {
            HStack(spacing: 12) {
                // Thumbnail placeholder
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 50, height: 70)
                    .overlay {
                        Image(systemName: iconName)
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text(file.name)
                        .font(.headline)
                        .lineLimit(2)

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
    }

    private var iconName: String {
        switch file.fileType {
        case .cbz, .cbr, .cb7, .cba, .zip, .rar, .sevenZip:
            return "book.closed"
        case .pdf:
            return "doc.fill"
        case .folder:
            return "folder"
        default:
            return "photo"
        }
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

        FileRowView(file: ComicFile(
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
        ))
    }
}
