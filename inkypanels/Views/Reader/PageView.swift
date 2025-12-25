import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct PageView: View {
    let page: ComicPage

    var body: some View {
        Group {
            if let imageData = page.imageData,
               let image = createImage(from: imageData) {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                placeholderView
            }
        }
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

            Text("Page \(page.index + 1)")
                .font(.headline)
                .foregroundStyle(.white)

            Text(page.fileName)
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

        PageView(page: ComicPage(
            index: 0,
            fileName: "page_001.jpg"
        ))
    }
}
