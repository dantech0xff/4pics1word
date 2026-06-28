# Code Review — Correct-Word Celebration Animation

**Date:** 2026-06-28 · **Reviewer:** code-review skill · **Verdict:** ✅ Ship after optional `TileFX.zero` fix

## Scope
- **Files reviewed:** `PuzzleState.swift`, `AppModel.swift`, `AppRootView.swift`, `WinView.swift`, `Feedback.swift`, `AnswerSlots.swift`, `GameView.swift`, `AppModelTests.swift`, `AppModelCelebrationTests.swift`, `PuzzleStateTests.swift` (+ all 5 phase docs)
- **LOC analyzed:** ~280 added/changed across 9 source + 1 new test file
- **Focus:** celebration window between solve-detection and WinView sheet
- **Verification run:** `build-for-testing` ✅, `4pics1wordTests` ✅ (incl. 8 new + 2 updated tests), on iPhone 17 / iOS 26.5
- **Updated plans:** `plan.md` (status → implemented-verified, phase table, verification log)

## Overall Assessment
Clean, faithful implementation of the HYBRID architecture. State machine is sound, idempotency holds under MainActor serialization, cancellation is comprehensive, reduce-motion gates are consistent. Reward/persist/advance remain synchronous (no progress-loss risk). Test coverage for the new lifecycle is thorough. One real conformance bug (`TileFX.zero`), otherwise only nits.

## Answers to the 7 Verification Questions

1. **Concurrency safety — OK.** Both `celebrationTask` (AppModel) and `waveTask` (GameView) are `@MainActor`-isolated (project default `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`). Both re-check `!Task.isCancelled` after every `Task.sleep`. `try?` swallows `CancellationError`, so the explicit flag check is the correct mitigation. No data races (single actor), no capture-then-mutate ordering hazards. The whole `evaluate() → onSolved → handleSolved → phase=.celebrating → spawn safety-net` chain runs synchronously on MainActor before any await, so the observer (`onChange(solvedToken)`) always sees `.celebrating` already set.

2. **Idempotency — OK.** `completeSolve()` guards on `phase == .celebrating` and flips exactly once. Reward is applied in `handleSolved`, **not** in `completeSolve()`, so double-call cannot double-credit coins or double-advance the index. Covered by `completeSolveIsIdempotent` (asserts index/coins/reward stable across 2nd call) and `rewardAppliedBeforeCompleteSolve`. Because both callers (GameView wave-end + AppModel safety-net) are MainActor, they serialize; the loser sees `phase == .won` and no-ops.

3. **State machine — OK.** Transitions: `.home → .playing → .celebrating → .won`. `exitToHome()` / `nextLevel()` / `resetProgress()` all cancel `celebrationTask`, and `exitToHome`/`resetProgress` also clear `gameState`. The dismiss-mid-celebration-then-return path is explicitly tested (`exitToHomeCancelsCelebration`): after exit, phase=`.home`, gameState=nil, and a stray `completeSolve()` cannot resurrect `.won` (guard fails). GameView's `.onDisappear` cancels `waveTask` when the cover dismisses. No orphan states.

4. **keyframeAnimator signature — OK.** `keyframeAnimator(initialValue:trigger:content:keyframes:)` (the trigger variant) is one-shot per trigger value change; iOS 26 SDK exposes no `repeatCount` on it. The `repeatCount:1` mentioned in `phase-02` is correctly **omitted** — documented deviation. Re-trigger works because `celebrate` alternates `false→true→false` across solves (every change restarts the keyframes).

5. **Reduce-motion path — OK, consistent.** GameView's `onChange(solvedToken)` short-circuits to `onSolved()` before constructing a Task; AnswerSlots' `slotTile` returns the plain `base` (no keyframeAnimator) when `reduceMotion`. Both read the same `@Environment(\.accessibilityReduceMotion)`. Note: reduce-motion users also skip the success chime (plan-sanctioned per phase-04 R5 — "jump straight to sheet").

6. **Memory/cycles — OK.** AppModel safety-net uses `[weak self]` (correct; AppModel is a class). GameView's waveTask does **not** need `[weak self]` — GameView is a struct (no `self` cycle). The Task captures `state` (PuzzleState ref) and `onSolved` (closure capturing AppModel); neither captures the Task back, so no cycle. Captures release when the Task completes or is cancelled (`.onDisappear` / `onChange(puzzle.id)`). PuzzleState may marginally outlive `gameState=nil` (held by an in-flight Task) until cancellation — harmless, bounded.

7. **Plan compliance — High.** All R-requirements across phases 01–05 satisfied. Intentional, documented deviations: (a) `repeatCount:1` dropped (SDK); (b) the tail sleep is hardcoded `320ms` instead of `Double(max(n-1,0))*0.08 + 0.40 - n*0.08` — but that expression is **mathematically constant at 0.32s for all n**, so the hardcode is an equivalent, cleaner simplification (comment is accurate).

## Critical Issues
None.

## High Priority Findings
None.

## Medium Priority Findings

### M1 — `TileFX.zero` violates `VectorArithmetic` contract (`AnswerSlots.swift:115`)
```swift
var scale: CGFloat = 1.0          // default
static var zero: TileFX { TileFX() }   // ⇒ scale == 1.0
```
`VectorArithmetic.zero` must be the additive identity: `x + zero == x`. Here `x + zero = TileFX(scale: x.scale + 1, …)` ≠ `x`. The `+`/`-`/`scale(by:)` ops are themselves correct, so keyframe interpolation (`a + (b - a).scaled(by: t)`) — which never invokes `zero` — works and the visible animation is right. The bug is latent: masked because every track has an explicit leading `CubicKeyframe(<value>, duration: stagger)` that supplies the pre-peak value, so SwiftUI never falls back to `zero` as a baseline.

**Why flag it:** (1) It's a real protocol-conformance correctness bug; (2) if SwiftUI's keyframe engine ever consults `zero` (e.g. pre-first-keyframe fill, or a future OS), scale would jump to 1.0×neutral incorrectly; (3) trivial fix.

**Fix (review-only — do not apply):**
```swift
static var zero: TileFX { TileFX(scale: 0, angleRad: 0, glow: 0) }
```
Keep `initialValue: TileFX()` (scale=1 = neutral visual) at the call site — `initialValue` is independent of the protocol's `zero`. No visible behavior change today; future-proofs the conformance.

## Low Priority Findings

### L1 — `Feedback.win()` is now dead code (`Feedback.swift:24`)
`WinView.onAppear { Feedback.win() }` was the only caller; its removal (phase-01 R5) leaves `win()` with zero call sites (verified via `rg`). Phase-03 R5 explicitly said "leave `win()` unchanged" for minimal diff, so this is plan-compliant — but it's now orphaned. Either delete it or add a `// retained for …` note. Not blocking.

### L2 — Safety-net (2.0s) can pre-empt the wave for very long words
Wave-onSolved lands at `n*0.08 + 0.32`s. For n≤20 this is ≤1.92s (< 2.0s safety-net) — fine. For hypothetical n≥22 the safety-net fires first: `completeSolve()` flips to `.won` (sheet presents) but does **not** cancel GameView's `waveTask`, so haptic taps would continue briefly under the sheet. 4pics1word words are far shorter, so practically unreachable. If you want belt-and-suspenders: have `completeSolve()`'s phase flip also cause the waveTask's post-sleep guard to bail (it already will — `onSolved()`→`completeSolve()` no-ops, and the next iteration's `Task.isCancelled` is the only missing piece; consider cancelling waveTask when phase leaves `.celebrating`). Optional.

## NITs
- **N1:** `Feedback` now has two parallel light-impact paths — `tap()` (fresh generator) vs `celebrationTap()` (cached `lightGen`). Intentional (minimal diff), documented in source comment, but a future reader may wonder. Fine.
- **N2:** `TileFX` defines `+=`/`-=` which `VectorArithmetic` doesn't require. Harmless convenience; leave or drop.
- **N3:** `AnswerSlots.slotTile` computed array is re-evaluated per slot per render. Trivial at n≤10; mentioning only for completeness.

## Positive Observations
- **`completeSolve()` design is exemplary:** single guard (`phase == .celebrating`) makes idempotency, cancellation-safety, and no-resurrection all fall out of one check. Moving reward OUT of `completeSolve` into `handleSolved` is the key insight that kills the double-credit risk.
- **Safety-net Task** is a thoughtful guard against the observer-race where GameView's `onChange` might miss the token (e.g. view dismissed mid-wave before wiring). 2s cap guarantees no stuck `.celebrating`.
- **Stagger-as-leading-keyframe trick** — single shared `@State celebrate` + per-tile leading `CubicKeyframe(neutral, duration: index*0.08)` achieves the L→R wave with zero per-tile timers/dicts. Genuinely DRY.
- **Tail-sleep simplification** — recognizing `total - n*0.08 ≡ 0.32s` (constant) and hardcoding it is cleaner than the plan's dynamic formula, and the comment documents the math.
- **Test design** correctly avoids asserting `Task.sleep` timing (non-deterministic) and exercises the lifecycle synchronously via `completeSolve()`. The 8 new tests cover flip/idempotent/no-op-home/no-op-playing/reward-timing/exit/next/reset — comprehensive.
- **Cancellation hooks** are present at every exit: `nextLevel` / `exitToHome` / `resetProgress` / GameView `onChange(puzzle.id)` / `onDisappear` / pre-retrigger.
- **Reward/persist/index-advance kept synchronous** — zero progress-loss surface even if celebration is aborted. This was the right call.

## Recommended Actions
1. **(M1, recommended before merge)** Fix `TileFX.zero` to return all-zeros. One-line change; prevents a latent conformance bug. Verify animation still looks identical in Simulator.
2. **(L1, optional)** Delete `Feedback.win()` or annotate its retention.
3. **(L2, optional, YAGNI-likely)** Skip unless long words are planned.
4. **(QA)** Run the phase-05 Manual QA Checklist on a Taptic-Engine iPhone — Simulator cannot verify haptics by design. Specifically: normal solve, reveal-hint solve (locked tiles animate), reduce-motion ON, haptics-OFF, background-mid-wave, exit-mid-wave, last-level wrap.
5. **Update `plan.md`** — done (status → implemented-verified, phase table, this review linked).

## Metrics
- **Type coverage:** N/A (Swift, no metrics tooling) — build is warning-clean for the changed files.
- **Test coverage:** `4pics1wordTests` ✅ all green. New lifecycle paths (celebrating/completeSolve/cancellation/idempotency) fully covered. Reduce-motion and animation visuals are UI-side-effects → unit-test-exempt per plan; require manual/device QA.
- **Linting issues:** 0 from this change. (Pre-existing Swift 6 main-actor `Settings: Encodable` warning in `AppModelTests.swift:73-74` is unrelated and out of scope.)
- **Pre-existing failures:** `SolveFlowUITests/testSolveLevel1` — confirmed unrelated (duplicate "S" tiles in pool). Not introduced here.

## Unresolved Questions
- None blocking. The only judgment call is whether to treat M1 as merge-blocking; recommendation is **yes** (1-line fix, eliminates a real if-latent contract violation), but it does not affect current visible behavior or test outcomes.
