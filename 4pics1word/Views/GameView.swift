import SwiftUI

/// The main gameplay screen: pictures, answer slots, letter bank, hint bar.
/// Driven entirely by a PuzzleState (@Observable). Phase 5 wraps this in a fullScreenCover
/// and presents WinView as a sheet on `state.phase == .won`.
struct GameView: View {
    let state: PuzzleState
    let levelNumber: Int
    var onExit: () -> Void = {}
    /// Fired at celebration-wave end → `AppModel.completeSolve()` → `.won` → WinView sheet.
    var onSolved: () -> Void = {}
    /// Fired when the player taps an unaffordable hint and chooses "Watch Ad" in the insufficient-
    /// coins alert. AppRootView wires it to `ads.showRewarded { grantRewardCoins(…) }`.
    var onWatchAd: () -> Void = {}

    @State private var zoomedIndex: Int?
    @State private var waveTask: Task<Void, Never>?
    @State private var wrongTask: Task<Void, Never>?
    @State private var showInsufficientCoins = false
    @Namespace private var zoomNS
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
        .alert("Not enough coins", isPresented: $showInsufficientCoins) {
            Button("Watch Ad (+\(Economy.rewardedAdPayout))") { onWatchAd() }
            Button("Not now", role: .cancel) {}
        } message: {
            Text("Watch a short ad to earn \(Economy.rewardedAdPayout) coins for hints?")
        }
        .onChange(of: state.wrongAttemptToken) { _, new in
            // Wrong submit: AnswerSlots self-observes `wrongAttemptToken` for the red
            // glow + shake; GameView owns the haptic + the deferred clear (single source
            // of truth for the post-animation tile reset).
            guard new > 0 else { return }
            wrongTask?.cancel()
            Feedback.wrong()
            if reduceMotion {
                // Skip FX AND the delay; clear is functional, only glow+shake is decorative.
                state.clearWrongAttempt()
                return
            }
            wrongTask = Task { @MainActor in
                // ≥ WrongFX animation tail (0.36s); pads to let the last shake settle.
                try? await Task.sleep(for: .milliseconds(550))
                guard !Task.isCancelled else { return }
                state.clearWrongAttempt()
            }
        }
        .onChange(of: state.solvedToken) { _, new in
            // AnswerSlots self-observes `solvedToken` for the visual wave; GameView owns
            // the haptic loop + sheet-timing (single source of truth for completion).
            guard new > 0 else { return }
            waveTask?.cancel()
            if reduceMotion {
                // Skip the celebration entirely; straight to sheet.
                onSolved()
                return
            }
            let n = state.slotCount
            waveTask = Task { @MainActor in
                Feedback.prepareCelebration()
                for _ in 0..<n {
                    guard !Task.isCancelled else { return }
                    Feedback.celebrationTap(intensity: 0.7)
                    try? await Task.sleep(for: .milliseconds(80))
                }
                guard !Task.isCancelled else { return }
                Feedback.celebrationChime()
                // Tail aligns with the last tile's visual settle (~0.40s post-stagger end).
                try? await Task.sleep(for: .milliseconds(320))
                guard !Task.isCancelled else { return }
                onSolved()
            }
        }
        .onChange(of: state.puzzle.id) { _, _ in
            zoomedIndex = nil
            waveTask?.cancel()
            wrongTask?.cancel()
        }
        .onDisappear {
            waveTask?.cancel()
            wrongTask?.cancel()
        }
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
            Text("Level \(levelNumber)")
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
            PictureGrid(
                puzzleId: state.puzzle.id,
                copyrights: state.puzzle.copyrights,
                zoomedIndex: zoomedIndex,
                namespace: zoomNS,
                onTap: zoom,
                onDismiss: dismissZoom
            )
            .padding(.horizontal)
            AnswerSlots(state: state)
                .padding(.horizontal)
        }
    }

    // MARK: Hint bar

    private var hintBar: some View {
        HStack(spacing: 14) {
            hintButton(label: "Reveal", icon: "lightbulb", cost: HintCost.reveal, enabled: state.canAttemptReveal) {
                if state.canReveal { state.revealHint() } else { showInsufficientCoins = true }
            }
            hintButton(label: "Remove", icon: "minus.circle", cost: HintCost.remove, enabled: state.canAttemptRemove) {
                if state.canRemove { state.removeHint() } else { showInsufficientCoins = true }
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

    // MARK: Image zoom

    private func zoom(_ index: Int) { setZoom(index) }

    private func dismissZoom() { setZoom(nil) }

    private func setZoom(_ index: Int?) {
        if reduceMotion {
            zoomedIndex = index
        } else {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) { zoomedIndex = index }
        }
    }
}
