import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Fit mode for image display
enum FitMode: String, CaseIterable, Identifiable {
    case fit = "Fit"
    case fitWidth = "Fit Width"
    case fitHeight = "Fit Height"
    case actualSize = "Actual Size"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .fit: return "arrow.up.left.and.arrow.down.right"
        case .fitWidth: return "arrow.left.and.right"
        case .fitHeight: return "arrow.up.and.down"
        case .actualSize: return "1.square"
        }
    }
}

/// A zoomable, pannable image view for comic reading
struct ZoomableImageView: View {
    let imageURL: URL?
    let imageData: Data?

    /// Fit mode for initial display
    var fitMode: FitMode = .fit

    /// Called when user taps (not drags/pinches) - only when at 1x zoom
    var onTap: ((CGPoint, CGSize) -> Void)?

    /// Called when user swipes horizontally - only when at 1x zoom
    /// Parameter is the horizontal translation (negative = swipe left, positive = swipe right)
    var onSwipe: ((CGFloat) -> Void)?

    // MARK: - State

    @State private var currentScale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var imageSize: CGSize = .zero
    @State private var lastContainerSize: CGSize = .zero

    // MARK: - Constants

    private let minScale: CGFloat = 1.0
    private let maxScale: CGFloat = 5.0
    private let doubleTapScale: CGFloat = 2.5

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            let containerSize = geometry.size

            ZStack {
                if let image = loadImage() {
                    image
                        .resizable()
                        .aspectRatio(contentMode: contentMode(for: fitMode))
                        .frame(
                            width: frameWidth(for: containerSize),
                            height: frameHeight(for: containerSize)
                        )
                        .scaleEffect(currentScale)
                        .offset(offset)
                        .background(
                            GeometryReader { imageGeometry in
                                Color.clear
                                    .onAppear {
                                        imageSize = imageGeometry.size
                                    }
                                    .onChange(of: imageGeometry.size) { _, newSize in
                                        imageSize = newSize
                                    }
                            }
                        )
                        .gesture(combinedGesture(containerSize: containerSize))
                        .onTapGesture(count: 2) {
                            handleDoubleTap(containerSize: containerSize)
                        }
                        .onTapGesture(count: 1) { location in
                            handleSingleTap(at: location, containerSize: containerSize)
                        }
                } else {
                    placeholderView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .onChange(of: geometry.size) { oldSize, newSize in
                handleContainerSizeChange(from: oldSize, to: newSize)
            }
            .onAppear {
                lastContainerSize = geometry.size
            }
        }
        .onChange(of: imageURL) { _, _ in
            resetZoom()
        }
    }

    private func handleContainerSizeChange(from oldSize: CGSize, to newSize: CGSize) {
        // Reset zoom on significant size change (orientation change)
        let widthChanged = abs(oldSize.width - newSize.width) > 50
        let heightChanged = abs(oldSize.height - newSize.height) > 50
        if widthChanged || heightChanged {
            resetZoom()
        }
        lastContainerSize = newSize
    }

    // MARK: - Image Loading

    private func loadImage() -> Image? {
        if let url = imageURL {
            return createImage(from: url)
        }
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

    // MARK: - Fit Mode Calculations

    private func contentMode(for mode: FitMode) -> ContentMode {
        switch mode {
        case .fit, .fitWidth, .fitHeight:
            return .fit
        case .actualSize:
            return .fill
        }
    }

    private func frameWidth(for containerSize: CGSize) -> CGFloat? {
        switch fitMode {
        case .fit:
            return nil // Let SwiftUI determine
        case .fitWidth:
            return containerSize.width
        case .fitHeight:
            return nil
        case .actualSize:
            return nil
        }
    }

    private func frameHeight(for containerSize: CGSize) -> CGFloat? {
        switch fitMode {
        case .fit:
            return nil
        case .fitWidth:
            return nil
        case .fitHeight:
            return containerSize.height
        case .actualSize:
            return nil
        }
    }

    // MARK: - Gestures

    private func combinedGesture(containerSize: CGSize) -> some Gesture {
        SimultaneousGesture(
            magnifyGesture(containerSize: containerSize),
            dragGesture(containerSize: containerSize)
        )
    }

    private func magnifyGesture(containerSize: CGSize) -> some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let newScale = lastScale * value.magnification
                currentScale = min(max(newScale, minScale), maxScale)
            }
            .onEnded { _ in
                lastScale = currentScale
                constrainOffset(containerSize: containerSize)
            }
    }

    private func dragGesture(containerSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { value in
                // Only allow panning when zoomed in
                guard currentScale > 1.0 else { return }

                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { value in
                // When not zoomed, treat as swipe for page navigation
                if currentScale <= 1.0 {
                    onSwipe?(value.translation.width)
                } else {
                    lastOffset = offset
                    constrainOffset(containerSize: containerSize)
                }
            }
    }

    // MARK: - Tap Handling

    private func handleDoubleTap(containerSize: CGSize) {
        withAnimation(.easeInOut(duration: 0.3)) {
            if currentScale > 1.0 {
                // Zoomed in - reset to 1x
                resetZoom()
            } else {
                // At 1x - zoom to doubleTapScale
                currentScale = doubleTapScale
                lastScale = doubleTapScale
            }
        }
    }

    private func handleSingleTap(at location: CGPoint, containerSize: CGSize) {
        // Only forward taps when not zoomed
        guard currentScale <= 1.0, let onTap = onTap else { return }
        onTap(location, containerSize)
    }

    // MARK: - Zoom Management

    private func resetZoom() {
        currentScale = 1.0
        lastScale = 1.0
        offset = .zero
        lastOffset = .zero
    }

    private func constrainOffset(containerSize: CGSize) {
        // Calculate how much the scaled image extends beyond container
        let scaledWidth = imageSize.width * currentScale
        let scaledHeight = imageSize.height * currentScale

        let maxOffsetX = max(0, (scaledWidth - containerSize.width) / 2)
        let maxOffsetY = max(0, (scaledHeight - containerSize.height) / 2)

        withAnimation(.easeOut(duration: 0.2)) {
            offset.width = min(max(offset.width, -maxOffsetX), maxOffsetX)
            offset.height = min(max(offset.height, -maxOffsetY), maxOffsetY)
            lastOffset = offset
        }
    }

    // MARK: - Placeholder

    private var placeholderView: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("Loading...")
                .font(.headline)
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.gray.opacity(0.1))
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        ZoomableImageView(
            imageURL: nil,
            imageData: nil,
            fitMode: .fit
        )
    }
}
