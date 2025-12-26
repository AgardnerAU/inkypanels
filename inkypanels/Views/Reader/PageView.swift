import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Displays a single comic page from either a file URL or inline data
struct PageView: View {
    /// Entry metadata for this page
    let entry: ArchiveEntry

    /// URL of the extracted image file (preferred)
    let imageURL: URL?

    /// Fallback: inline image data (legacy support)
    let imageData: Data?

    init(entry: ArchiveEntry, imageURL: URL? = nil, imageData: Data? = nil) {
        self.entry = entry
        self.imageURL = imageURL
        self.imageData = imageData
    }

    var body: some View {
        Group {
            if let image = loadImage() {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                placeholderView
            }
        }
    }

    private func loadImage() -> Image? {
        // Try URL first (new architecture)
        if let url = imageURL {
            return createImage(from: url)
        }

        // Fallback to inline data (legacy)
        if let data = imageData {
            return createImage(from: data)
        }

        return nil
    }

    private func createImage(from url: URL) -> Image? {
        #if canImport(UIKit)
        guard let uiImage = UIImage(contentsOfFile: url.path) else { return nil }
        return Image(uiImage: uiImage)
        #elseif canImport(AppKit)
        guard let nsImage = NSImage(contentsOfFile: url.path) else { return nil }
        return Image(nsImage: nsImage)
        #else
        return nil
        #endif
    }

    private func createImage(from data: Data) -> Image? {
        #if canImport(UIKit)
        guard let uiImage = UIImage(data: data) else { return nil }
        return Image(uiImage: uiImage)
        #elseif canImport(AppKit)
        guard let nsImage = NSImage(data: data) else { return nil }
        return Image(nsImage: nsImage)
        #else
        return nil
        #endif
    }

    private var placeholderView: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("Page \(entry.index + 1)")
                .font(.headline)
                .foregroundStyle(.white)

            Text(entry.fileName)
                .font(.caption)
                .foregroundStyle(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.gray.opacity(0.1))
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        PageView(
            entry: ArchiveEntry(
                path: "page_001.jpg",
                uncompressedSize: 1024,
                index: 0
            )
        )
    }
}
