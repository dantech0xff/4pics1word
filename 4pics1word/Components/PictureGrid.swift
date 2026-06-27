import SwiftUI

/// 2×2 grid of the four puzzle pictures.
struct PictureGrid: View {
    let puzzleId: Int

    private let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(1...4, id: \.self) { index in
                PuzzleImage(puzzleId: puzzleId, index: index)
                    .aspectRatio(1, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
            }
        }
    }
}
