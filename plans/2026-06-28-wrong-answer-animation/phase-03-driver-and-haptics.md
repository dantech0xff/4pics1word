# Phase 03 — GameView Driver + Haptics

## Context Links
- Research (state-deferral): `research/researcher-02-state-deferral-report.md` §3, §4, §5
- Research (animation): `research/researcher-01-animation-report.md` §4
- Scout: `scout/scout-01-codebase-report.md` §3, §4, §6
- Mirror: `../2026-06-28-correct-word-animation/plan.md` (wave Task pattern)
- Source: `4pics1word/Views/GameView.swift`, `4pics1word/Game/Feedback.swift`

## Overview
- Priority: P2. Status: Pending. Deps: Phase 01 (`clearWrongAttempt()` API). Parallel with Phase 02 (different file).
- Replace GameView's whole-view shake (`shakeOffset` + `triggerShake()`) with a `wrongTask: Task` that fires `Feedback.wrong()`, sleeps 550ms (≥ animation tail), then calls `state.clearWrongAttempt()`. Reduce-motion: skip sleep, clear immediately. Cancel `wrongTask` on puzzle-id change + `onDisappear`.

## Key Insights
- **Remove whole-view shake (researcher-01 §4):** existing `triggerShake()` (L150-156) shakes the ENTIRE view (pictures, header, bank) via `shakeOffset` — diffuse, unfocused, only 0.20s (twitch). Per-tile shake in AnswerSlots (phase 02) is row-focused and DRY. Delete both `shakeOffset` (L13) and `triggerShake()`; remove the `.offset(x: shakeOffset)` modifier (L30) and the `triggerShake()` call (L32).
- **KEEP `Feedback.wrong()`** at trigger time — single sharp `.error` pulse, not a per-oscillation rhythm (researcher-01 unresolved-Q). Celebration's per-tile tap pattern doesn't apply to errors.
- **550ms sleep > 0.36s animation** (phase 02 budget) ⇒ clear lands after the last shake settles. Hardcoded constant — same approach celebration used (`total-sleep` hardcoded 320ms, plan §Verification).
- **No safety-net Task** (unlike celebration's 2.0s `celebrationTask`): wrong is local PuzzleState tile state, scoped to one GameView lifetime. `onDisappear` cancels `wrongTask`; `AppModel.exitToHome` nilles `gameState` ⇒ tiles die with it. No stuck-state survives across screens (researcher-02 §3).
- **`try?` + idempotent finisher** handles the only in-flight failure mode (`Task.sleep` throw). `clearWrongAttempt()` no-ops if `!isRejecting`.
- **Mirror wave Task cancellation hooks** (L61-67): `onChange(state.puzzle.id)` + `onDisappear` already cancel `waveTask`; extend them to cancel `wrongTask` too.
- **Reduce-motion parity with celebration** (`GameView.swift:40-44`): inline skip-and-clear branch — clear is functional, only glow+shake is decorative.

## Requirements
- **R1** Add `@State private var wrongTask: Task<Void, Never>?` (mirror `waveTask` L15).
- **R2** Rewrite `onChange(of: state.wrongAttemptToken)` (L31-34): cancel previous `wrongTask`, fire `Feedback.wrong()`, branch on `reduceMotion` (immediate clear) vs Task (sleep 550ms → clear).
- **R3** Extend `onChange(of: state.puzzle.id)` (L61-64) and `onDisappear` (L65-67) to cancel `wrongTask` alongside `waveTask`.
- **R4** Remove `shakeOffset` (L13), `.offset(x: shakeOffset)` (L30), `triggerShake()` (L150-156), and the MARK comment "Shake on wrong" (L148).
- **R5** `Feedback.wrong()` call preserved at trigger time.
- **R6** `clearWrongAttempt()` called exactly once per wrong attempt (idempotent guard in PuzzleState absorbs duplicate calls).
- **N1** No new safety-net Task. No new AppPhase. No new haptic methods on `Feedback`.
- **N2** Celebration `waveTask` + `onChange(solvedToken)` block (L35-60) untouched.

## Architecture
```swift
// State (add under waveTask, L15):
@State private var wrongTask: Task<Void, Never>?

// Remove (L13):
// @State private var shakeOffset: CGFloat = 0

// Remove from body (L30):
// .offset(x: shakeOffset)

// Rewrite onChange (L31-34):
.onChange(of: state.wrongAttemptToken) { _, new in
    guard new > 0 else { return }
    wrongTask?.cancel()
    Feedback.wrong()
    if reduceMotion {
        state.clearWrongAttempt()        // functional clear; FX skipped
        return
    }
    wrongTask = Task { @MainActor in
        // ≥ WrongFX animation tail (0.36s); pads to let last shake settle.
        try? await Task.sleep(for: .milliseconds(550))
        guard !Task.isCancelled else { return }
        state.clearWrongAttempt()
    }
}

// Extend cancellation hooks (L61-67):
.onChange(of: state.puzzle.id) { _, _ in
    zoomedIndex = nil
    waveTask?.cancel()
    wrongTask?.cancel()
}
.onDisappear {
    waveTask?.cancel()
    wrongTask?.cancel()
}

// Delete (L148-156): MARK comment + entire triggerShake() func.
```

## Related Code Files
- **MODIFY** `4pics1word/Views/GameView.swift`
  - L13: delete `@State private var shakeOffset: CGFloat = 0`.
  - L15 (after `waveTask`): add `@State private var wrongTask: Task<Void, Never>?`.
  - L30: delete `.offset(x: shakeOffset)`.
  - L31-34: replace `triggerShake(); Feedback.wrong()` with the R2 driver body above.
  - L62-63 (inside `onChange(state.puzzle.id)`): add `wrongTask?.cancel()`.
  - L65-67 (inside `onDisappear`): add `wrongTask?.cancel()`.
  - L148-156: delete MARK `// Shake on wrong` + the entire `triggerShake()` function.
- **NO CHANGE** `4pics1word/Game/Feedback.swift` — `Feedback.wrong()` (L19-22) reused as-is.

## Implementation Steps
1. Add `@State private var wrongTask: Task<Void, Never>?` (mirror `waveTask`).
2. Rewrite `onChange(of: state.wrongAttemptToken)` per R2.
3. Add `wrongTask?.cancel()` to `onChange(of: state.puzzle.id)` and `onDisappear`.
4. Delete `shakeOffset` state property (L13), `.offset(x: shakeOffset)` modifier (L30), MARK comment + `triggerShake()` (L148-156).
5. Build green.
6. Manual: submit a wrong word → glow+shake (phase 02) then clear; rapid wrong submits don't deadlock; exit-to-home mid-rejection leaves no stuck tiles.

## Todo List
- [ ] `wrongTask` state property added
- [ ] `onChange(wrongAttemptToken)` rewritten (cancel → Feedback.wrong → reduceMotion branch / sleep→clear)
- [ ] `wrongTask?.cancel()` added to puzzle-id change + onDisappear
- [ ] `shakeOffset` state + `.offset(x:)` modifier removed
- [ ] `triggerShake()` + MARK comment removed
- [ ] `Feedback.wrong()` retained at trigger
- [ ] Build succeeds

## Success Criteria
- Wrong submit fires `Feedback.wrong()` once at trigger, then ~550ms later tiles return to bank.
- Reduce-motion: clear happens immediately (same frame as `onChange`), no haptic delay race (haptic still fires).
- Rapid wrong submits: previous `wrongTask` cancelled before new one starts; no double-clear (idempotent guard absorbs any race).
- Exit-to-home mid-rejection: `onDisappear` cancels `wrongTask`; `gameState` dropped by `AppModel.exitToHome`; no tile residue.
- Solve flow unaffected: `waveTask` + `onChange(solvedToken)` block unchanged.

## Risk Assessment
- **R-ClearSkipped (MED):** if `Task.sleep` throws and `try?` swallows, the `guard !Task.isCancelled` could short-circuit. Mitigation: `try?` returns `nil` on throw (cancellation), `guard !Task.isCancelled` then exits cleanly. `clearWrongAttempt()` is called on the normal path; idempotent guard makes any later defensive call safe. No safety-net Task needed (researcher-02 §3).
- **R-StuckRejecting (LOW):** if GameView dismisses before the Task body runs `clearWrongAttempt()`, `isRejecting` stays `true` on the discarded PuzzleState — but the PuzzleState itself is dropped (`gameState = nil`). New puzzle = fresh `PuzzleState` with `isRejecting == false`. No stuck-state survives.
- **R-HapticLatency (LOW):** `Feedback.wrong()` uses a fresh `UINotificationFeedbackGenerator` (Feedback.swift L21) — no `prepare()` call. Cold-first-fire latency is acceptable for an error pulse (unlike celebration which calls `prepareCelebration()`).
- **R-WholeViewShakeDeadCode (LOW):** removing `triggerShake` may orphan references — verify no other call sites (grep `triggerShake\|shakeOffset` returns only GameView.swift).

## Security Considerations
- None. UI driver; no I/O, no privileged state.

## Next Steps
- → Phase 04: Swift Testing `PuzzleStateWrongAttemptTests` + build + manual QA.
