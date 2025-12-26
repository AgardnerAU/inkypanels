import SwiftUI

struct ReaderControlsView: View {
    let comic: ComicFile
    @Binding var currentPage: Int
    let totalPages: Int
    @Binding var fitMode: FitMode
    var isBookmarked: Bool = false
    var onToggleBookmark: (() -> Void)?
    let onClose: () -> Void
    let settings = ReaderSettings.shared

    @State private var isEditingPage = false
    @State private var pageInputText = ""
    @FocusState private var isPageInputFocused: Bool

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

            displayOptionsMenu
        }
        .padding()
    }

    private var displayOptionsMenu: some View {
        Menu {
            // Display Options only
            Toggle(isOn: Binding(
                get: { settings.showPageGap },
                set: { settings.showPageGap = $0 }
            )) {
                Label("Page Gap", systemImage: "rectangle.split.2x1")
            }

            Toggle(isOn: Binding(
                get: { settings.smartSpreadDetection },
                set: { settings.smartSpreadDetection = $0 }
            )) {
                Label("Smart Spreads", systemImage: "sparkles.rectangle.stack")
            }
        } label: {
            Image(systemName: "gearshape")
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Circle().fill(.ultraThinMaterial))
        }
    }

    private var fitModeMenu: some View {
        Menu {
            // Fit Mode Section
            Section("Fit Mode") {
                ForEach(FitMode.allCases) { mode in
                    Button {
                        fitMode = mode
                    } label: {
                        if fitMode == mode {
                            Label(mode.rawValue, systemImage: "checkmark")
                        } else {
                            Text(mode.rawValue)
                        }
                    }
                }
            }

            // Page Layout Section (per-orientation)
            Section(settings.isLandscape ? "Layout (Landscape)" : "Layout (Portrait)") {
                Picker("Layout", selection: Binding(
                    get: { settings.currentLayout },
                    set: { settings.setCurrentLayout($0) }
                )) {
                    ForEach(PageLayout.allCases) { layout in
                        Label(layout.rawValue, systemImage: layout.icon)
                            .tag(layout)
                    }
                }
            }

            // Reading Direction Section
            Section("Reading Direction") {
                Picker("Direction", selection: Binding(
                    get: { settings.readingDirection },
                    set: { settings.readingDirection = $0 }
                )) {
                    ForEach(ReadingDirection.allCases) { direction in
                        Label(direction.rawValue, systemImage: direction.icon)
                            .tag(direction)
                    }
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
        Group {
            if isEditingPage {
                pageInputField
            } else {
                pageDisplayButton
            }
        }
    }

    private var pageDisplayButton: some View {
        Button {
            pageInputText = "\(currentPage + 1)"
            isEditingPage = true
            isPageInputFocused = true
        } label: {
            Text("Page \(currentPage + 1) of \(totalPages)")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Capsule().fill(.ultraThinMaterial))
        }
    }

    private var pageInputField: some View {
        HStack(spacing: 4) {
            Text("Page")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.white)

            TextField("", text: $pageInputText)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.white)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .frame(width: 50)
                .focused($isPageInputFocused)
                .onSubmit {
                    navigateToEnteredPage()
                }

            Text("of \(totalPages)")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.white)

            Button {
                navigateToEnteredPage()
            } label: {
                Image(systemName: "arrow.right.circle.fill")
                    .foregroundStyle(.white)
            }

            Button {
                isEditingPage = false
                isPageInputFocused = false
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Capsule().fill(.ultraThinMaterial))
        .onChange(of: isPageInputFocused) { _, focused in
            if !focused {
                isEditingPage = false
            }
        }
    }

    private func navigateToEnteredPage() {
        if let pageNumber = Int(pageInputText) {
            // Convert from 1-based user input to 0-based index
            let targetPage = max(0, min(totalPages - 1, pageNumber - 1))
            currentPage = targetPage
        }
        isEditingPage = false
        isPageInputFocused = false
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
