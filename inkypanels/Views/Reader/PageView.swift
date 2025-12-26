import SwiftUI

/// Displays a single comic page with zoom and pan support
struct PageView: View {
    /// Entry metadata for this page
    let entry: ArchiveEntry

    /// URL of the extracted image file (preferred)
    let imageURL: URL?

    /// Fallback: inline image data (legacy support)
    let imageData: Data?

    /// Fit mode for the image
    var fitMode: FitMode = .fit

    /// Called when user taps (only when not zoomed)
    var onTap: ((CGPoint, CGSize) -> Void)?

    /// Called when user swipes horizontally (only when not zoomed)
    var onSwipe: ((CGFloat) -> Void)?

    init(
        entry: ArchiveEntry,
        imageURL: URL? = nil,
        imageData: Data? = nil,
        fitMode: FitMode = .fit,
        onTap: ((CGPoint, CGSize) -> Void)? = nil,
        onSwipe: ((CGFloat) -> Void)? = nil
    ) {
        self.entry = entry
        self.imageURL = imageURL
        self.imageData = imageData
        self.fitMode = fitMode
        self.onTap = onTap
        self.onSwipe = onSwipe
    }

    var body: some View {
        ZoomableImageView(
            imageURL: imageURL,
            imageData: imageData,
            fitMode: fitMode,
            onTap: onTap,
            onSwipe: onSwipe
        )
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
