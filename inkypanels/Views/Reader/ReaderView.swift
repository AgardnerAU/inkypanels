import SwiftUI

struct ReaderView: View {
    let comic: ComicFile

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: ReaderViewModel
    @State private var fitMode: FitMode = .fit

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
                } else if viewModel.entries.isEmpty {
                    emptyView
                } else {
                    pageContent(in: geometry)
                }

                if viewModel.showControls && !viewModel.isLoading && !viewModel.entries.isEmpty {
                    controlsOverlay
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        #if os(iOS)
        .statusBarHidden(!viewModel.showControls)
        #endif
        .task {
            viewModel.configureProgressService(modelContext: modelContext)
            await viewModel.loadComic()
        }
        .onDisappear {
            Task {
                await viewModel.cleanup()
            }
        }
    }

    // MARK: - Loading State

    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView(value: viewModel.extractionProgress)
                .progressViewStyle(.linear)
                .frame(width: 250)
                .tint(.white)

            Text(viewModel.loadingStatus)
                .font(.headline)
                .foregroundStyle(.white)

            Text(comic.name)
                .font(.subheadline)
                .foregroundStyle(.gray)
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
            if let entry = viewModel.currentEntry {
                PageView(
                    entry: entry,
                    imageURL: viewModel.currentPageURL,
                    fitMode: fitMode,
                    onTap: { location, size in
                        viewModel.handleTap(at: location, in: size)
                    }
                )
                .id(entry.id)
                .transition(.opacity)
                .gesture(swipeGesture)
            }
        }
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
            fitMode: $fitMode,
            isBookmarked: viewModel.isCurrentPageBookmarked,
            onToggleBookmark: { viewModel.toggleBookmark() },
            onClose: { dismiss() }
        )
        .transition(.opacity)
    }

    // MARK: - Gestures

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
