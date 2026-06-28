# Researcher 02 — State-Deferral Design (Wrong-Answer)

Mirrors celebration HYBRID (`AppModel.swift:62-89`, `GameView.swift:46-59`) but wrong stays inside `PuzzleState` — no AppPhase change. Token bumped immediately (UI trigger), tile-clear deferred to a `clearWrongAttempt()` finisher that GameView calls after the glow+shake animation.

## §1 `evaluate()` split + new `clearWrongAttempt()`

Refactor `PuzzleState.swift:171-186`. Solve branch untouched. Wrong branch: do NOT clear, just flag + token.

```swift
private func evaluate() {
    if isSolved {
        phase = .won
        solvedToken &+= 1
        onSolved(self)
    } else {
        // Defer tile-clear until clearWrongAttempt() fires from GameView post-animation.
        isRejecting = true
        wrongAttemptToken &+= 1
    }
}

/// GameView calls this AFTER glow+shake finishes (or immediately under reduce-motion).
/// Re-derives the clear set from current tile state ⇒ idempotent if invoked twice.
/// Gates itself off by flipping isRejecting=false at end.
func clearWrongAttempt() {
    guard isRejecting else { return }            // idempotent no-op
    for index in tiles.indices {
        if tiles[index].slot != nil && !tiles[index].locked {   // preserve locked hints (I7)
            let id = tiles[index].id
            tiles[index].slot = nil
            if !bankOrder.contains(id) { bankOrder.append(id) }
        }
    }
    isRejecting = false
}
```

Notes:
- `isRejecting` set BEFORE token bump ⇒ by the time `onChange(wrongAttemptToken)` fires, flag is already `true` (race-free; `@MainActor` default isolation serializes anyway).
- `clearWrongAttempt()` is `func` (not `private`) — GameView calls it. Mark `public` to module via `internal` (default).
- Idempotent guard lets a safety-net Task call it without racing the primary driver.

## §2 Gating flag — DRY computed prop

Add to `PuzzleState` (near `wrongAttemptToken`, L32):

```swift
private(set) var isRejecting: Bool = false
private var canMutate: Bool { phase == .playing && !isRejecting }
```

Rewrite guards DRY (single source of truth):
- `placeTile` L109: `guard canMutate else { return }`
- `removeTile` L119: `guard canMutate else { return }`
- `canReveal` L92: `canMutate && coins >= HintCost.reveal && hasUnrevealedSlot`
- `canRemove` L93: `canMutate && coins >= HintCost.remove && surplusBankCount > 0`
- `canShuffle` L94: `canMutate && bankOrder.count > 1`
- `revealHint`/`removeHint`/`shuffle` already early-return on `can*` computed props ⇒ transitively gated, no body change needed.

**Why DRY wins over `&& !isRejecting` everywhere:** single edit point if gating rules evolve; hint buttons auto-disable because their `.disabled(!enabled)` binds to `canReveal`/`canRemove`/`canShuffle` (`GameView.swift:145`). The `phase == .playing` literal in `placeTile`/`removeTile` collapses into `canMutate`.

## §3 GameView Task driver (mirrors wave Task at L46-59)

Replace `GameView.swift:31-34`:

```swift
@State private var wrongTask: Task<Void, Never>?

.onChange(of: state.wrongAttemptToken) { _, new in
    guard new > 0 else { return }
    wrongTask?.cancel()
    Feedback.wrong()
    if reduceMotion { state.clearWrongAttempt(); return }   // §4
    wrongTask = Task { @MainActor in
        // glow+shake duration; researcher-01 confirms exact (target ~0.55s).
        try? await Task.sleep(for: .milliseconds(550))
        guard !Task.isCancelled else { return }
        state.clearWrongAttempt()
    }
}
```

Also cancel on puzzle-change / disappear (mirror L61-67):
```swift
.onChange(of: state.puzzle.id) { _, _ in wrongTask?.cancel() }
.onDisappear { wrongTask?.cancel() }
```

### Safety-net Task? — **NO** (unlike celebration's 2.0s `celebrationTask`)
- Celebration safety-net exists because `AppPhase.celebrating` is **app-wide semantic state** — a missed `completeSolve()` would freeze the user on a dead screen with no sheet.
- Wrong rejection is **local PuzzleState tile state**, scoped to one GameView lifetime. If GameView dismisses (`onDisappear` cancels `wrongTask`), `gameState` is nilled (`AppModel.exitToHome` L104) ⇒ tiles die with it. No stuck-state survives across screens.
- Within a live GameView, the only failure is `Task.sleep` throwing — already handled by `try?` + `clearWrongAttempt()` idempotency. Adding a safety-net duplicates the primary driver with no failure mode it covers.

If paranoia demanded: a `defer { state.clearWrongAttempt() }` inside the Task body is cheaper than a second timer. But even that is unnecessary — `clearWrongAttempt()` already no-ops if `!isRejecting`.

## §4 reduce-motion path

Inline in §3 driver: skip the sleep, call `clearWrongAttempt()` synchronously. Clear is functional (must happen); only glow+shake are decorative. Mirrors celebration's `if reduceMotion { onSolved(); return }` at `GameView.swift:40-44`. AnswerSlots WrongFX keyframes will also self-skip via their own `reduceMotion` check (researcher-01's concern).

## §5 Edge cases

(a) **Double-wrong in flight** — `isRejecting == true` ⇒ `canMutate == false` ⇒ `placeTile` no-ops at L109 guard ⇒ `isFull` never re-fires ⇒ `evaluate()` not re-entered. **Confirmed** single rejection in flight. Token cannot bump twice.

(b) **Exit-to-home mid-rejection** — `AppModel.exitToHome()` (L97-106) cancels `celebrationTask` only; wrong lives in GameView's `wrongTask`. `onDisappear` (L65-67) cancels it. `gameState = nil` (L104) drops the PuzzleState entirely. No tile residue — tiles are owned by the discarded state. **Acceptable.** No action needed; just add `wrongTask?.cancel()` to `onDisappear` (already pattern-present for `waveTask`).

(c) **Locked hint tiles** — `clearWrongAttempt()` preserves `&& !tiles[index].locked` predicate verbatim from old `evaluate()` (L178). Locked hints stay slotted (invariant I7). **Confirmed.**

(d) **Rapid wrong → solve** — impossible: rejection blocks all `placeTile`, so the board cannot mutate toward a solve during the window. Post-clear, normal play resumes.

## §6 No new AppPhase needed

Celebration needs `AppPhase.celebrating` because it **defers a cross-screen transition** (WinView sheet) owned by `AppModel` — two consumers (`showGame`/`showWin`) must agree on the semantic. Wrong defers **only tile state**, which is wholly owned by `PuzzleState` and consumed only by GameView's subtree. No sheet, no cross-model invariant, no enum pollution. `isRejecting: Bool` is the minimal mirror — same argument scout-01 §5 made for token-vs-phase, applied to the gate flag.

Adding `.rejecting` to `PuzzlePhase` would force sweeps of every `phase == .playing` site (placeTile, removeTile, canReveal/canRemove/canShuffle, WinView gating) for zero new capability — violates YAGNI.

## §7 Test surface — `PuzzleStateWrongAttemptTests`

New file `4pics1wordTests/PuzzleStateWrongAttemptTests.swift`, `import Testing`, `@testable import _pics1word`. Mirror `AppModelCelebrationTests` style.

```swift
@Suite struct PuzzleStateWrongAttemptTests {
    @Test func wrongEvaluate_doesNotClearTiles_setsFlag_bumpsToken()
    @Test func clearWrongAttempt_clearsNonLocked_preservesLocked_resetsFlag()
    @Test func duringRejection_placeTile_isNoOp()
    @Test func duringRejection_revealHint_isNoOp()
    @Test func duringRejection_canReveal_canRemove_canShuffle_allFalse()
    @Test func clearWrongAttempt_isIdempotent_secondCallNoOp()
    @Test func correctSolve_afterRejectionClear_works()   // regression: full happy-path after a wrong
}
```

Assertions per test:
- (a) fill board wrong → `evaluate` is private ⇒ test via `placeTile(lastTile)`; assert `slotTile` still non-nil for all filled slots, `state.isRejecting == true`, `state.wrongAttemptToken == 1`.
- (b) pre-place one `locked: true` tile (or call `revealHint` then fill wrong) → call `clearWrongAttempt()` → assert non-locked slotted tiles now `slot == nil` & in `bankOrder`; locked tile unchanged; `isRejecting == false`.
- (c) during rejection, `placeTile(bankId)` → assert tile still `slot == nil`, bankOrder unchanged.
- (d) `canReveal`/`canRemove`/`canShuffle` evaluate to `false` while `isRejecting == true` even when coins/conditions otherwise allow.

## Unresolved questions
- Exact glow+shake duration — researcher-01 owns the timing budget. Placeholder 550ms in §3; final value flows from animation spec. `Feedback.wrong()` already wired, no change.
- Whether AnswerSlots WrongFX should also observe `isRejecting` to early-end keyframes on reduce-motion — orthogonal (researcher-01), but recommend yes for symmetry.
