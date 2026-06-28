import SwiftUI

/// 2×2 grid of the four puzzle pictures. Tapping a cell zooms that picture to fill
/// the whole grid area (via a shared `matchedGeometryEffect` namespace), leaving the
/// rest of the screen (answer slots, hints, letter bank) visible and interactive.
struct PictureGrid: View {
    let puzzleId: Int
    let copyrights: [String]
    let zoomedIndex: Int?
    let namespace: Namespace.ID
    let onTap: (Int) -> Void
    let onDismiss: () -> Void

    private let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(1...4, id: \.self) { index in
                cell(for: index)
            }
        }
        .overlay {
            if let i = zoomedIndex {
                ImageZoomOverlay(
                    index: i,
                    puzzleId: puzzleId,
                    credit: credit(for: i),
                    namespace: namespace,
                    onDismiss: onDismiss
                )
            }
        }
    }

    @ViewBuilder
    private func cell(for index: Int) -> some View {
        if zoomedIndex == index {
            // Reserve the cell's slot so the grid keeps its 2×2 shape while zoomed;
            // the matched-geometry image is rendered by the grid overlay instead.
            Color.clear.aspectRatio(1, contentMode: .fit)
        } else {
            Button {
                onTap(index)
            } label: {
                PuzzleImage(puzzleId: puzzleId, index: index)
                    .aspectRatio(1, contentMode: .fit)
                    .matchedGeometryEffect(id: ImageZoomOverlay.matchedGeometryId(for: index), in: namespace)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
                    .contentShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Picture \(index) of 4")
            .accessibilityHint("Tap to enlarge")
        }
    }

    private func credit(for index: Int) -> String? {
        guard copyrights.indices.contains(index - 1) else { return nil }
        return copyrights[index - 1]
    }
}
