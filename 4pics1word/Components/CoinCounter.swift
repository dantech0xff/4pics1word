import SwiftUI

/// Coin counter chip with a coin glyph.
struct CoinCounter: View {
    let coins: Int

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "circle.fill")
                .foregroundStyle(.yellow)
                .font(.caption)
            Text("\(coins)")
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(Color.yellow.opacity(0.18)))
        .accessibilityLabel("Coins: \(coins)")
    }
}
