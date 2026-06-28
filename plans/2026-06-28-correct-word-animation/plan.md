---
title: "Correct-Word Celebration Animation Before Win Sheet"
description: "Play a per-tile zoom/rotate/glow wave + haptics on the answer row after solve, then present WinView sheet."
status: implemented-verified
priority: P2
effort: 7h
branch: master
tags: [feature, frontend, animation, haptics, ios]
created: 2026-06-28
completed: 2026-06-28
---

# Correct-Word Celebration Animation Before Win Sheet

## Overview
Insert a celebration window between solve-detection and sheet presentation. On correct solve: defer `AppPhase.won`, run a left→right wave (scale+rotate+green glow per tile) synced with light-impact haptics, then a success chime, THEN present WinView. Reduce-motion users skip straight to the sheet.

## Architecture Decision (Option picked: HYBRID)
- **Option A** (explicit `.celebrating` phase) — clean state semantics; ripples enum into every `switch`.
- **Option B** (pure `solvedToken` + deferred `Task`) — mirrors `wrongAttemptToken`; but deferring a state-machine transition behind a token is a smell + needs a separate flag to know "are we mid-celebration".
- **✅ HYBRID (picked):** `AppPhase.celebrating` **on AppModel only** (2 trivial consumers: `showGame`, `showWin`) + `solvedToken: Int` on **PuzzleState** (UI trigger, DRY with `wrongAttemptToken`, no new GameView→AppModel plumbing). **PuzzlePhase untouched** → existing `state.phase == .won` tests + invariant-sweep (`while phase != .won`) unaffected. Only `model.phase == .won` assertions (2, in `AppModelTests`) need update. Cancellation trivial: wave Task re-checks `model.phase == .celebrating` before flipping to `.won`.

## Timing Budget
- stagger `0.08s`/tile, active ≈ `0.40s`/tile. `total = (n-1)·0.08 + 0.40` ⇒ n=4→0.64s, n=7→0.88s, n=10→1.12s. Snappy, celebratory. Wall ≈ 0.7–1.2s.

## Phases
| # | Phase | Status | Effort | Link |
|---|-------|--------|--------|------|
| 1 | Solve-detection + deferred `.won` | ✅ Done | 1.5h | [phase-01](./phase-01-solve-detection.md) |
| 2 | Per-tile celebration modifier (KeyframeAnimator) | ✅ Done | 2h | [phase-02-tile-celebration.md) |
| 3 | Haptics (per-tile light + final chime, prepare()) | ✅ Done | 1h | [phase-03-haptics.md) |
| 4 | Wave driver in GameView + cancellation | ✅ Done | 1.5h | [phase-04-wave-driver.md) |
| 5 | Tests + manual verify | ✅ Done (unit; QA pending device) | 1h | [phase-05-tests-verify.md) |

## Verification (2026-06-28)
- `build-for-testing` ✅ SUCCEEDED (iPhone 17 sim, iOS 26.5).
- `4pics1wordTests` ✅ SUCCEEDED — all unit tests pass incl. 8 new `AppModelCelebrationTests` + 2 updated `AppModelProgressLoopTests` + `solvedToken==1` assertion.
- Code review: see `2026-06-28-correct-word-animation-review.md`. 1 MEDIUM (`TileFX.zero` contract), 2 LOW (`Feedback.win()` now dead; safety-net vs very-long-word edge), rest NIT.
- Deviations (intentional): `repeatCount:1` omitted (iOS 26 trigger-variant has no such param); `total-sleep` hardcoded to 320ms (= `total - n*0.08`, constant for all n).
- Still open: device QA for haptics (Simulator silent by design); pre-existing `SolveFlowUITests/testSolveLevel1` failure (unrelated, duplicate-tile pool issue).

## Dependencies
- Phase 01 first (creates `solvedToken` + `.celebrating` + `completeSolve()`).
- Phase 02, 03 parallel after 01.
- Phase 04 depends on 02 + 03.
- Phase 05 depends on all.

## Key Constraints (AGENTS.md)
- Module name `_pics1word` (no `_` prefix on new types). `@MainActor` default isolation. File-system synchronized groups ⇒ drop `.swift` files, **no pbxproj edits**. Swift Testing (`import Testing`, `struct`+`@Test`). iOS 26.5 ⇒ `KeyframeAnimator(repeatCount:trigger:)` (iOS18+) available. Reuse `accessibilityReduceMotion` (GameView L14). Reuse locked-tile green convention (`Color.green.opacity(0.18)`).

## Decisions (locked via validation interview 2026-06-28)
1. **Stagger style → Sequential L→R wave.** Tiles animate one-by-one with ~80ms stagger.
2. **Total duration → ~1.0s.** `total = (n-1)·0.08 + 0.40s`. Snappy, celebratory.
3. **Architecture → Hybrid.** `AppPhase.celebrating` on AppModel + `solvedToken` on PuzzleState. PuzzlePhase untouched.
4. **`Feedback.win()` placement → Wave-end (before sheet).** Move out of `WinView.onAppear`; success chime lands with last tile. Phase 03 removes the WinView.onAppear call.
5. **Locked-tile animation → Animate ALL tiles.** Locked hint tiles participate in the wave for unified rhythm.
