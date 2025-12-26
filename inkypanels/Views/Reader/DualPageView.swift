import SwiftUI

/// Displays two comic pages side by side for landscape reading
struct DualPageView: View {
    let leftEntry: ArchiveEntry?
    let rightEntry: ArchiveEntry?
    let leftImageURL: URL?
    let rightImageURL: URL?
    let fitMode: FitMode
    let showGap: Bool
    let readingDirection: ReadingDirection
    var onTap: ((CGPoint, CGSize) -> Void)?
    var onSwipe: ((CGFloat) -> Void)?

    private let gapWidth: CGFloat = 4

    var body: some View {
        GeometryReader { geometry in
            let pageWidth = (geometry.size.width - (showGap ? gapWidth : 0)) / 2

            HStack(spacing: showGap ? gapWidth : 0) {
                // First page (left for LTR, right for RTL)
                if readingDirection == .leftToRight {
                    leftPageView(width: pageWidth, containerSize: geometry.size)
                    rightPageView(width: pageWidth, containerSize: geometry.size)
                } else {
                    // RTL: right page comes first visually
                    rightPageView(width: pageWidth, containerSize: geometry.size)
                    leftPageView(width: pageWidth, containerSize: geometry.size)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func leftPageView(width: CGFloat, containerSize: CGSize) -> some View {
        Group {
            if let entry = leftEntry {
                singlePageView(entry: entry, imageURL: leftImageURL, width: width, containerSize: containerSize, isLeft: true)
            } else {
                placeholderView(width: width)
            }
        }
    }

    @ViewBuilder
    private func rightPageView(width: CGFloat, containerSize: CGSize) -> some View {
        Group {
            if let entry = rightEntry {
                singlePageView(entry: entry, imageURL: rightImageURL, width: width, containerSize: containerSize, isLeft: false)
            } else {
                placeholderView(width: width)
            }
        }
    }

    private func singlePageView(entry: ArchiveEntry, imageURL: URL?, width: CGFloat, containerSize: CGSize, isLeft: Bool) -> some View {
        ZoomableImageView(
            imageURL: imageURL,
            imageData: nil,
            fitMode: fitMode,
            onTap: { location, _ in
                // Adjust location for the full container
                let adjustedX: CGFloat
                if isLeft {
                    adjustedX = location.x
                } else {
                    adjustedX = location.x + width + (showGap ? gapWidth : 0)
                }
                onTap?(CGPoint(x: adjustedX, y: location.y), containerSize)
            },
            onSwipe: onSwipe
        )
        .frame(width: width)
        .clipped()
    }

    private func placeholderView(width: CGFloat) -> some View {
        Color.clear
            .frame(width: width)
    }
}

#Preview("Dual Page - LTR") {
    ZStack {
        Color.black.ignoresSafeArea()

        DualPageView(
            leftEntry: ArchiveEntry(path: "page_001.jpg", uncompressedSize: 1024, index: 0),
            rightEntry: ArchiveEntry(path: "page_002.jpg", uncompressedSize: 1024, index: 1),
            leftImageURL: nil,
            rightImageURL: nil,
            fitMode: .fit,
            showGap: true,
            readingDirection: .leftToRight
        )
    }
}

#Preview("Dual Page - RTL") {
    ZStack {
        Color.black.ignoresSafeArea()

        DualPageView(
            leftEntry: ArchiveEntry(path: "page_001.jpg", uncompressedSize: 1024, index: 0),
            rightEntry: ArchiveEntry(path: "page_002.jpg", uncompressedSize: 1024, index: 1),
            leftImageURL: nil,
            rightImageURL: nil,
            fitMode: .fit,
            showGap: true,
            readingDirection: .rightToLeft
        )
    }
}
