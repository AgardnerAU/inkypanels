import SwiftUI

struct ReaderControlsView: View {
    let comic: ComicFile
    @Binding var currentPage: Int
    let totalPages: Int
    @Binding var fitMode: FitMode
    var isBookmarked: Bool = false
    var onToggleBookmark: (() -> Void)?
    let onClose: () -> Void

    var body: some View {
        VStack {
            topBar
            Spacer()
            bottomBar
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: 12) {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(.ultraThinMaterial))
            }

            Spacer()

            Text(comic.name)
                .font(.headline)
                .foregroundStyle(.white)
                .lineLimit(1)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Capsule().fill(.ultraThinMaterial))

            Spacer()

            fitModeMenu

            Button {
                onToggleBookmark?()
            } label: {
                Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                    .font(.title2)
                    .foregroundStyle(isBookmarked ? .yellow : .white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(.ultraThinMaterial))
            }
        }
        .padding()
    }

    private var fitModeMenu: some View {
        Menu {
            ForEach(FitMode.allCases) { mode in
                Button {
                    fitMode = mode
                } label: {
                    Label(mode.rawValue, systemImage: mode.icon)
                }
            }
        } label: {
            Image(systemName: fitMode.icon)
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Circle().fill(.ultraThinMaterial))
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        VStack(spacing: 12) {
            if totalPages > 1 {
                PageSliderView(
                    currentPage: $currentPage,
                    totalPages: totalPages
                )
            }

            pageIndicator
        }
        .padding()
        .background(
            LinearGradient(
                colors: [.clear, .black.opacity(0.5)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }

    private var pageIndicator: some View {
        Text("Page \(currentPage + 1) of \(totalPages)")
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Capsule().fill(.ultraThinMaterial))
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        ReaderControlsView(
            comic: ComicFile(
                url: URL(fileURLWithPath: "/test.cbz"),
                name: "Batman: The Long Halloween",
                fileType: .cbz,
                fileSize: 10_000_000,
                modifiedDate: Date()
            ),
            currentPage: .constant(5),
            totalPages: 100,
            fitMode: .constant(.fit),
            isBookmarked: true,
            onToggleBookmark: { print("Bookmark toggled") },
            onClose: { print("Close tapped") }
        )
    }
}
