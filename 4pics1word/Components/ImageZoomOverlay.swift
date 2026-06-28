import SwiftUI

/// Zoomed puzzle picture shown over the `PictureGrid` area only (not fullscreen).
/// Fills the grid's bounding box via the host `.overlay`, shares a
/// `matchedGeometryEffect` id with the source cell, shows the photo credit as a
/// pill in the bottom-right corner, and dismisses on tap. Everything outside the
/// grid (answer slots, hints, letter bank) stays visible and interactive.
struct ImageZoomOverlay: View {
    let index: Int
    let puzzleId: Int
    let credit: String?
    let namespace: Namespace.ID
    let onDismiss: () -> Void

    var body: some View {
        Button(action: onDismiss) {
            PuzzleImage(puzzleId: puzzleId, index: index)
                .aspectRatio(1, contentMode: .fit)
                .matchedGeometryEffect(id: Self.matchedGeometryId(for: index), in: namespace)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(alignment: .bottomTrailing) {
                    if let credit {
                        Text("© \(credit)")
                            .font(.caption2)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(.black.opacity(0.45)))
                            .padding(8)
                            .transition(.opacity)
                    }
                }
                .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Double-tap to close")
        .accessibilityAction(named: "Dismiss") { onDismiss() }
    }

    private var accessibilityLabel: String {
        var label = "Picture \(index), enlarged"
        if let credit { label += ". Credit: \(credit)" }
        return label
    }

    /// Single source of truth for the matched-geometry id shared with `PictureGrid`.
    static func matchedGeometryId(for index: Int) -> String { "puzzle-img-\(index)" }
}
