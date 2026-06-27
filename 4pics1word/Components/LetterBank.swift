import SwiftUI

/// Scrambled letter bank. Tap a tile to place it in the first empty slot.
struct LetterBank: View {
    let state: PuzzleState

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 6)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(state.bankTiles) { tile in
                Button {
                    state.placeTile(tile.id)
                    Feedback.tap()
                } label: {
                    Text(String(tile.character))
                }
                .buttonStyle(TileButtonStyle())
            }
        }
        .animation(.snappy, value: state.bankTiles.map(\.id))
    }
}
