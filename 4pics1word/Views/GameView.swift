import SwiftUI

/// The main gameplay screen: pictures, answer slots, letter bank, hint bar.
/// Driven entirely by a PuzzleState (@Observable). Phase 5 wraps this in a fullScreenCover
/// and presents WinView as a sheet on `state.phase == .won`.
struct GameView: View {
    let state: PuzzleState
    let levelNumber: Int
    let totalLevels: Int
    var onExit: () -> Void = {}

    @State private var shakeOffset: CGFloat = 0

    var body: some View {
        VStack(spacing: 16) {
            header
            content
            Spacer(minLength: 0)
            hintBar
            LetterBank(state: state)
                .padding(.horizontal)
        }
        .padding(.vertical, 12)
        .background(Color(.systemBackground).ignoresSafeArea())
        .offset(x: shakeOffset)
        .onChange(of: state.wrongAttemptToken) { _, _ in
            triggerShake()
        }
        .overlay { winOverlay }
    }

    // MARK: Header

    private var header: some View {
        HStack {
            Button {
                onExit()
            } label: {
                Image(systemName: "xmark")
                    .font(.headline)
                    .padding(8)
            }
            Spacer()
            Text("Level \(levelNumber) of \(totalLevels)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
            CoinCounter(coins: state.coins)
        }
        .padding(.horizontal)
    }

    // MARK: Pictures + slots

    private var content: some View {
        VStack(spacing: 20) {
            PictureGrid(puzzleId: state.puzzle.id)
                .padding(.horizontal)
            AnswerSlots(state: state)
                .padding(.horizontal)
        }
    }

    // MARK: Hint bar

    private var hintBar: some View {
        HStack(spacing: 14) {
            hintButton(label: "Reveal", icon: "lightbulb", cost: HintCost.reveal, enabled: state.canReveal) {
                state.revealHint()
            }
            hintButton(label: "Remove", icon: "minus.circle", cost: HintCost.remove, enabled: state.canRemove) {
                state.removeHint()
            }
            hintButton(label: "Shuffle", icon: "shuffle", cost: HintCost.shuffle, enabled: state.canShuffle) {
                state.shuffle()
            }
        }
        .padding(.horizontal)
    }

    private func hintButton(label: String, icon: String, cost: Int, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon).font(.title3)
                Text(label).font(.caption.weight(.semibold))
                if cost > 0 {
                    Text("\(cost)").font(.caption2).foregroundStyle(.secondary)
                } else {
                    Text("Free").font(.caption2).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(enabled ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.08))
            )
            .foregroundStyle(enabled ? Color.accentColor : .secondary)
        }
        .disabled(!enabled)
    }

    // MARK: Shake on wrong

    private func triggerShake() {
        let amplitude: CGFloat = 10
        withAnimation(.easeInOut(duration: 0.05)) { shakeOffset = amplitude }
        withAnimation(.easeInOut(duration: 0.05).delay(0.05)) { shakeOffset = -amplitude }
        withAnimation(.easeInOut(duration: 0.05).delay(0.10)) { shakeOffset = amplitude }
        withAnimation(.easeInOut(duration: 0.05).delay(0.15)) { shakeOffset = 0 }
    }

    // MARK: Win overlay (Phase 4 inline; Phase 5 replaces with WinView sheet)

    @ViewBuilder
    private var winOverlay: some View {
        if state.phase == .won {
            ZStack {
                Color.black.opacity(0.55).ignoresSafeArea()
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.green)
                    Text("Solved!")
                        .font(.title.weight(.bold))
                    Text(state.puzzle.solution)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(30)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
            }
            .transition(.opacity)
        }
    }
}
