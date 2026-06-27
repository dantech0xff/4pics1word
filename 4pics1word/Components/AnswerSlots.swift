import SwiftUI

/// Answer slots row. Tapping a filled, non-locked slot returns the tile to the bank.
struct AnswerSlots: View {
    let state: PuzzleState

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(state.slotTile.enumerated()), id: \.offset) { _, tile in
                if let tile {
                    slotTile(tile)
                } else {
                    emptySlot
                }
            }
        }
        .animation(.snappy, value: state.slotTile.map { $0?.id })
    }

    private var emptySlot: some View {
        RoundedRectangle(cornerRadius: 6)
            .strokeBorder(Color.secondary.opacity(0.4), lineWidth: 1)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.08)))
            .frame(height: 48)
            .frame(maxWidth: 56)
    }

    @ViewBuilder
    private func slotTile(_ tile: Tile) -> some View {
        Text(String(tile.character))
            .font(.title2.weight(.heavy))
            .foregroundStyle(tile.locked ? Color.green : .primary)
            .frame(height: 48)
            .frame(maxWidth: 56)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(tile.locked ? Color.green.opacity(0.18) : Color.secondary.opacity(0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(tile.locked ? Color.green : Color.secondary.opacity(0.35), lineWidth: tile.locked ? 2 : 1)
            )
            .contentShape(Rectangle())
            .onTapGesture {
                if !tile.locked { state.removeTile(tile.id) }
            }
    }
}
