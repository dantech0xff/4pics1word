# Phase 04 — Wave Driver in GameView + Cancellation

## Context Links
- Research: `researcher-01` §3,§5 (completion via stored Task; cancellation) + `researcher-02` A3, B1, B4 (haptic loop, sheet timing, cancellation guard)
- Source: `4pics1word/Views/GameView.swift` (L11-35, L117-123 shake precedent)

## Overview
- Priority: P2. Status: Pending. Deps: Phase 01 (`.celebrating`/`solvedToken`/`completeSolve`), Phase 02 (tile wave), Phase 03 (haptics).
- Drive the wave from `GameView`: observe `state.solvedToken` → run a stored cancellable `Task` that (a) triggers the visual wave (toggles `celebrate` via AnswerSlots — or AnswerSlots self-observes token; see decision), (b) runs the haptic loop, (c) on completion calls `model.completeSolve()` → `.won` → sheet. Reduce-motion shortcut skips wave, calls `completeSolve()` immediately.

## Key Insights
- **Single source of truth for timing:** the `Task` computes `total = (n-1)·0.08 + 0.40` and is the ONLY scheduler for haptics AND sheet flip. Visual wave is driven by `solvedToken`→`celebrate` toggle (AnswerSlots Phase 02) — same trigger, parallel systems, but timing aligns because both key off `0.08`/tile stagger baked into keyframes. [researcher-02 A3]
- **`withAnimation{...}completion:` is useless here** (KeyframeAnimator runs outside `withAnimation`). Use stored `Task.sleep`. [researcher-01 §3]
- **Cancellation MANDATORY** [researcher-02 B4]: store Task in `@State`; cancel on `onDisappear`, new-puzzle (`onChange(state.puzzle.id)`), and before each re-trigger. Re-check `!Task.isCancelled` AND `model.phase == .celebrating` after sleep — `try?` swallows `CancellationError`, so explicit flag check required.
- **Reduce-motion:** REUSE existing gate (GameView L14). Skip everything, call `completeSolve()` → instant sheet.
- GameView does NOT hold `AppModel` (signature L6-9: `state, levelNumber, onExit`). To call `completeSolve()`, pass a closure `var onSolved: () -> Void = {}` (cleaner than injecting whole model — KISS, testable). Wire `AppRootView` gameLayer to `model.completeSolve`.

## Requirements
- **R1** `onChange(of: state.solvedToken)` starts ONE wave Task; cancels any prior.
- **R2** Task: `prepareCelebration()` → haptic loop (n taps @ 0.08s) → `celebrationChime()` → `completeSolve()`.
- **R3** `total` sleep = `Double(max(n-1,0))·0.08 + 0.40` computed from `state.slotCount` at fire time.
- **R4** Post-sleep guard: `!Task.isCancelled && modelStillCelebrating` before `completeSolve()`. Pass `phase`-check via closure returning Bool OR just call `completeSolve()` (it's idempotent + checks `.celebrating` itself — Phase 01 R3). **Prefer:** rely on `completeSolve()`'s internal `.celebrating` guard. Simpler.
- **R5** `reduceMotion` ⇒ `completeSolve()` immediately, no Task, no haptic loop (optionally one chime — skip per "jump straight to sheet").
- **R6** Cancel wave Task on: `.onDisappear`, `onChange(of: state.puzzle.id)` (new puzzle / re-entry).
- **R7** `onSolved` closure param added to GameView; `AppRootView.gameLayer` passes `{ model.completeSolve() }`.

## Architecture
```
GameView
  @State private var waveTask: Task<Void, Never>?
  var onSolved: () -> Void = {}                 // NEW — AppRootView wires to model.completeSolve
  ...
  .onChange(of: state.solvedToken) { _, new in
      guard new > 0 else { return }
      if reduceMotion { onSolved(); return }     // skip wave
      waveTask?.cancel()
      let n = state.slotCount
      let total = Double(max(n-1,0))*0.08 + 0.40
      waveTask = Task { @MainActor in
          Feedback.prepareCelebration()
          for i in 0..<n {
              guard !Task.isCancelled else { return }
              Feedback.celebrationTap(intensity: 0.7)
              try? await Task.sleep(for: .milliseconds(80))
          }
          guard !Task.isCancelled else { return }
          Feedback.celebrationChime()
          try? await Task.sleep(for: .seconds(max(total - Double(n)*0.08, 0)))   // align to visual end (~0.40s tail)
          guard !Task.isCancelled else { return }
          onSolved()                             // → completeSolve() → .won → sheet
      }
  }
  .onChange(of: state.puzzle.id) { waveTask?.cancel() }   // extend existing L32-34
  .onDisappear { waveTask?.cancel() }
```
**Note on visual trigger:** AnswerSlots (Phase 02) self-observes `state.solvedToken` and toggles its own `celebrate` — GameView does NOT need to push a visual trigger. GameView's role here is haptics + sheet-timing. Keeps separation clean (AnswerSlots=visuals, GameView=orchestration).

## Related Code Files
- **MODIFY** `4pics1word/Views/GameView.swift`
  - L6-9 struct: add `var onSolved: () -> Void = {}`.
  - L11-14: add `@State private var waveTask: Task<Void, Never>?`.
  - After L31 (existing `onChange(wrongAttemptToken)`): add `.onChange(of: state.solvedToken)` block (R1–R5 logic).
  - L32-34 `onChange(state.puzzle.id)`: append `waveTask?.cancel()`.
  - Add `.onDisappear { waveTask?.cancel() }`.
- **MODIFY** `4pics1word/Views/AppRootView.swift`
  - L46-50 `gameLayer` GameView init: add `onSolved: { model.completeSolve() }`.

## Implementation Steps
1. GameView: add `onSolved` param + `waveTask` state.
2. Implement `.onChange(of: state.solvedToken)` (reduceMotion shortcut + Task with prepare/loop/chime/total-sleep/onSolved).
3. Extend `onChange(state.puzzle.id)` to cancel waveTask; add `.onDisappear` cancel.
4. AppRootView: pass `onSolved: { model.completeSolve() }`.
5. Build + run on Simulator (visual only — haptics silent); on device (haptics).

## Todo List
- [ ] `onSolved` param on GameView
- [ ] `waveTask` state
- [ ] `onChange(solvedToken)` wave driver (reduceMotion shortcut + Task)
- [ ] haptic loop + chime + total-sleep + onSolved
- [ ] cancel on puzzle.id change + onDisappear
- [ ] AppRootView wires `onSolved`
- [ ] Build green; device verify

## Success Criteria
- Solve a puzzle: tiles wave L→R (Phase 02), haptic taps fire per tile + chime at end (device), sheet slides up ~`total`s after solve.
- Reduce-motion ON: no wave, sheet appears immediately on solve.
- Background app mid-wave, return: no orphan sheet; safety-net (Phase 01) or cancelled Task prevents late pop.
- Dismiss to Home mid-wave: no sheet pops after.
- New puzzle via Next: prior wave Task cancelled; no bleed.

## Risk Assessment
- **R-LateSheet (MED):** If `try?` swallows cancel during sleep, `onSolved()` could fire after dismiss. Mitigation: `completeSolve()` itself checks `.celebrating` (Phase 01 R3) ⇒ idempotent no-op if user already exited (`.home`). Double-safe.
- **R-VisualHapticDesync (LOW):** Visual stagger baked in keyframes (`index·0.08`); haptic loop sleeps `0.08`/tile. Same cadence ⇒ aligned. Verify on device.
- **R-Reentrancy (LOW):** `solvedToken` fires once per solve; re-trigger only on next solve (new puzzle resets guard). `waveTask?.cancel()` before new Task covers edge.
- **R-AppBackgrounded (MED):** `Task.sleep` suspends in background; on resume may fire late. Mitigation: safety-net Task (Phase 01, 2s cap) + `completeSolve()` idempotency. Worst case sheet appears ~2s late — acceptable; never stuck.

## Security Considerations
- None. Local UI orchestration.

## Next Steps
- → Phase 05 (tests for token/deferral/idempotency + manual QA checklist).
