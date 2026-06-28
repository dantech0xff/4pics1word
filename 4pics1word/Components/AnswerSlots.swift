import SwiftUI

/// Answer slots row. Tapping a filled, non-locked slot returns the tile to the bank.
/// On solve (`state.solvedToken` change), plays a L→R celebration wave: scale + rotation
/// + green glow per tile via `KeyframeAnimator`. Reduce-motion users skip the wave.
struct AnswerSlots: View {
    let state: PuzzleState

    @State private var celebrate: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<state.slotCount, id: \.self) { index in
                if let tile = state.slotTile[index] {
                    slotTile(tile, index: index)
                } else {
                    emptySlot
                }
            }
        }
        .animation(.snappy, value: state.slotTile.map { $0?.id })
        .onChange(of: state.solvedToken) { _, _ in
            celebrate.toggle()
        }
    }

    private var emptySlot: some View {
        RoundedRectangle(cornerRadius: 6)
            .strokeBorder(Color.secondary.opacity(0.4), lineWidth: 1)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.08)))
            .frame(height: 48)
            .frame(maxWidth: 56)
    }

    @ViewBuilder
    private func slotTile(_ tile: Tile, index: Int) -> some View {
        let base = Text(String(tile.character))
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
            .compositingGroup()
            .contentShape(Rectangle())
            .onTapGesture {
                if !tile.locked { state.removeTile(tile.id) }
            }

        if reduceMotion {
            // Skip animation entirely; tile renders as-is.
            base
        } else {
            base
                .keyframeAnimator(
                    initialValue: TileFX(),
                    trigger: celebrate
                ) { content, fx in
                    content
                        .scaleEffect(fx.scale)
                        .rotationEffect(fx.angle)
                        .shadow(color: Color.green.opacity(0.9 * fx.glow), radius: 12 * fx.glow, y: 2)
                } keyframes: { _ in
                    // Leading idle keyframe per-tile produces the L→R stagger without
                    // per-tile timers: each tile's wave just starts later.
                    let stagger = Double(index) * 0.08
                    KeyframeTrack(\.scale) {
                        CubicKeyframe(1.0, duration: stagger)
                        CubicKeyframe(1.15, duration: 0.12)
                        CubicKeyframe(1.0, duration: 0.14)
                    }
                    KeyframeTrack(\.angleRad) {
                        CubicKeyframe(0.0, duration: stagger)
                        CubicKeyframe(-0.139, duration: 0.08)   // ~-8°
                        CubicKeyframe(0.139, duration: 0.10)    // ~+8°
                        CubicKeyframe(0.0, duration: 0.08)
                    }
                    KeyframeTrack(\.glow) {
                        CubicKeyframe(0.0, duration: stagger)
                        CubicKeyframe(1.0, duration: 0.12)
                        CubicKeyframe(0.0, duration: 0.22)
                    }
                }
        }
    }
}

/// Per-tile celebration keyframe values. Stored as animatable primitives so the
/// `VectorArithmetic` requirements (`+`, `-`, `scale`, `magnitudeSquared`) are trivial.
/// `angleRad` is exposed as `Angle` at the apply site.
private struct TileFX: VectorArithmetic {
    var scale: CGFloat = 1.0
    var angleRad: Double = 0.0
    var glow: CGFloat = 0.0

    var angle: Angle { .radians(angleRad) }

    var magnitudeSquared: Double {
        Double(scale) * Double(scale) + angleRad * angleRad + Double(glow) * Double(glow)
    }

    mutating func scale(by factor: Double) {
        scale *= factor
        angleRad *= factor
        glow *= factor
    }

    static var zero: TileFX { TileFX(scale: 0, angleRad: 0, glow: 0) }

    static func +(lhs: TileFX, rhs: TileFX) -> TileFX {
        TileFX(scale: lhs.scale + rhs.scale, angleRad: lhs.angleRad + rhs.angleRad, glow: lhs.glow + rhs.glow)
    }

    static func -(lhs: TileFX, rhs: TileFX) -> TileFX {
        TileFX(scale: lhs.scale - rhs.scale, angleRad: lhs.angleRad - rhs.angleRad, glow: lhs.glow - rhs.glow)
    }

    static func +=(lhs: inout TileFX, rhs: TileFX) { lhs = lhs + rhs }
    static func -=(lhs: inout TileFX, rhs: TileFX) { lhs = lhs - rhs }
}
