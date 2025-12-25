import SwiftUI

struct PageSliderView: View {
    @Binding var currentPage: Int
    let totalPages: Int

    @State private var isDragging: Bool = false
    @State private var dragValue: Double = 0

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Track
                Capsule()
                    .fill(.ultraThinMaterial)
                    .frame(height: 8)

                // Progress
                Capsule()
                    .fill(.white)
                    .frame(width: progressWidth(in: geometry), height: 8)

                // Thumb
                Circle()
                    .fill(.white)
                    .frame(width: 24, height: 24)
                    .shadow(radius: 4)
                    .offset(x: thumbOffset(in: geometry))
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isDragging = true
                        let percentage = max(0, min(1, value.location.x / geometry.size.width))
                        let page = Int(percentage * Double(totalPages - 1))
                        currentPage = page
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
        }
        .frame(height: 24)
        .padding(.horizontal, 12)
    }

    private func progressWidth(in geometry: GeometryProxy) -> CGFloat {
        guard totalPages > 1 else { return 0 }
        let percentage = CGFloat(currentPage) / CGFloat(totalPages - 1)
        return percentage * geometry.size.width
    }

    private func thumbOffset(in geometry: GeometryProxy) -> CGFloat {
        guard totalPages > 1 else { return 0 }
        let percentage = CGFloat(currentPage) / CGFloat(totalPages - 1)
        return percentage * (geometry.size.width - 24)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        VStack {
            PageSliderView(currentPage: .constant(25), totalPages: 100)
                .padding()
        }
    }
}
