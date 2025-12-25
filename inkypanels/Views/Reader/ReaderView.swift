import SwiftUI

struct ReaderView: View {
    let comic: ComicFile

    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: ReaderViewModel

    init(comic: ComicFile) {
        self.comic = comic
        self._viewModel = State(initialValue: ReaderViewModel(comic: comic))
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()

                if viewModel.isLoading {
                    loadingView
                } else if let error = viewModel.error {
                    errorView(error)
                } else if viewModel.pages.isEmpty {
                    emptyView
                } else {
                    pageContent(in: geometry)
                }

                if viewModel.showControls && !viewModel.isLoading && !viewModel.pages.isEmpty {
                    controlsOverlay
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        #if os(iOS)
        .statusBarHidden(!viewModel.showControls)
        #endif
        .task {
            await viewModel.loadComic()
        }
    }

    // MARK: - Loading State

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.white)

            Text("Loading \(comic.name)...")
                .font(.headline)
                .foregroundStyle(.white)
        }
    }

    // MARK: - Error State

    private func errorView(_ error: InkyPanelsError) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundStyle(.orange)

            Text("Failed to Open Comic")
                .font(.title2)
                .foregroundStyle(.white)

            Text(error.localizedDescription)
                .font(.body)
                .foregroundStyle(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            if let suggestion = error.recoverySuggestion {
                Text(suggestion)
                    .font(.caption)
                    .foregroundStyle(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            HStack(spacing: 16) {
                Button("Go Back") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .tint(.white)

                Button("Retry") {
                    Task { await viewModel.loadComic() }
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    // MARK: - Empty State

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.stack")
                .font(.system(size: 60))
                .foregroundStyle(.gray)

            Text("No Pages Found")
                .font(.title2)
                .foregroundStyle(.white)

            Text("This comic doesn't contain any readable images")
                .font(.body)
                .foregroundStyle(.gray)

            Button("Go Back") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Page Content

    private func pageContent(in geometry: GeometryProxy) -> some View {
        ZStack {
            if let page = viewModel.currentPage {
                PageView(page: page)
                    .id(page.id)
                    .transition(.opacity)
            }
        }
        .gesture(tapGesture(in: geometry))
        .gesture(swipeGesture)
        .animation(.easeInOut(duration: 0.2), value: viewModel.currentPageIndex)
    }

    // MARK: - Controls Overlay

    private var controlsOverlay: some View {
        ReaderControlsView(
            comic: comic,
            currentPage: Binding(
                get: { viewModel.currentPageIndex },
                set: { viewModel.goToPage($0) }
            ),
            totalPages: viewModel.totalPages,
            onClose: { dismiss() }
        )
        .transition(.opacity)
    }

    // MARK: - Gestures

    private func tapGesture(in geometry: GeometryProxy) -> some Gesture {
        SpatialTapGesture()
            .onEnded { value in
                viewModel.handleTap(at: value.location, in: geometry.size)
            }
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 50)
            .onEnded { value in
                viewModel.handleSwipe(translation: value.translation.width)
            }
    }
}

#Preview {
    ReaderView(comic: ComicFile(
        url: URL(fileURLWithPath: "/test.cbz"),
        name: "Test Comic",
        fileType: .cbz,
        fileSize: 10_000_000,
        modifiedDate: Date()
    ))
}
