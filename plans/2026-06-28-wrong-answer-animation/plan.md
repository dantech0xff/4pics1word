---
title: "Wrong-Answer Rejection Animation (Red Glow + Shake Before Dismiss)"
description: "Defer tile-clear on wrong submit; play red glow + per-tile shake, then clear. Mirrors the correct-word celebration HYBRID pattern."
status: implemented-verified
priority: P2
effort: 4h
branch: master
tags: [feature, frontend, animation, haptics, ios]
created: 2026-06-28
---

# Wrong-Answer Rejection Animation (Red Glow + Shake Before Dismiss)

## Overview
On full-but-wrong submit: do NOT clear tiles synchronously. Flag rejection, bump `wrongAttemptToken` (existing UI trigger), let `AnswerSlots` play a red-glow + per-tile shake (~0.55s), THEN GameView calls `clearWrongAttempt()` to return non-locked tiles to the bank. Reduce-motion: skip FX, clear immediately. Mirrors the celebration HYBRID but scoped to `PuzzleState` — no `AppPhase` change.

## Architecture Decision (HYBRID, scoped to PuzzleState)
- **Mirror of celebration:** `wrongAttemptToken` (PuzzleState L32) already exists as UI trigger — reuse (no new token). Add `isRejecting: Bool` gate flag alongside it; add `clearWrongAttempt()` finisher. Animation owns glow+shake in `AnswerSlots` (per-tile `keyframeAnimator`); GameView owns the deferral Task + haptic.
- **Why NOT `AppPhase.rejecting`:** celebration needed `.celebrating` because it defers a **cross-screen transition** (WinView sheet) owned by `AppModel` — two consumers (`showGame`/`showWin`) must agree. Wrong defers **only tile state**, wholly owned by `PuzzleState`, consumed only by `GameView`'s subtree. No sheet, no cross-model invariant. `isRejecting: Bool` is minimal — same YAGNI argument scout-01 §5/researcher-02 §6 made. Adding `.rejecting` to `PuzzlePhase` would force sweeps of every `phase == .playing` site for zero capability.
- **No safety-net Task** (unlike celebration's 2.0s `celebrationTask`): wrong lives in GameView's `wrongTask`; `onDisappear` cancels it and `gameState = nil` drops the PuzzleState entirely (researcher-02 §3). `clearWrongAttempt()` is idempotent (`guard isRejecting`) ⇒ a missed call cannot corrupt state.

## Timing Budget (~0.55s, snappier than celebration's 0.7–1.2s)
- Glow track: `0→1 (0.08s) → hold 1 (0.10s) → 0 (0.12s)` = **0.30s**.
- Shake track: decaying oscillation `0→-10→8→-5→3→-1.5→0` over **0.36s**.
- Tracks run parallel; animation ends at `max(0.30, 0.36)=0.36s`. GameView defers clear by **550ms** (pads the tail so the last shake settles before tiles lift). Exact keyframes in researcher-01 §2.

## Phases
| # | Phase | Status | Effort | Link |
|---|-------|--------|--------|------|
| 1 | Deferred clear in PuzzleState (`isRejecting` + `canMutate` + `clearWrongAttempt()`) | ✅ Done | 1.5h | [phase-01-deferred-clear.md](./phase-01-deferred-clear.md) |
| 2 | Per-tile rejection animation (WrongFX + red glow + shake) | ✅ Done | 1.5h | [phase-02-rejection-animation.md](./phase-02-rejection-animation.md) |
| 3 | GameView driver + haptics (wrongTask, remove old triggerShake) | ✅ Done | 0.5h | [phase-03-driver-and-haptics.md](./phase-03-driver-and-haptics.md) |
| 4 | Tests + build + manual QA | ✅ Done (auto-tests green; manual QA pending) | 0.5h | [phase-04-tests-verify.md](./phase-04-tests-verify.md) |

## Verification (2026-06-28)
- `xcodebuild … build` (iPhone 17 sim, iOS 26.5): **SUCCEEDED**.
- Unit tests `4pics1wordTests`: **66/66 PASS** (8 new `PuzzleStateWrongAttemptTests` + 2 updated `PuzzleStateWinTests` + all existing).
- Code review (code-reviewer subagent): **APPROVE WITH NITS** — nits were test-strength; tests hardened (added load-bearing `duringRejection_removeTile_isNoOp`; `revealHint`/`can*` tests now use pools that isolate the `canMutate` gate).
- UI tests (`4pics1wordUITests`) compiled clean; not executed (simulator session-clone timeout — environmental, not code). Manual QA on device recommended per phase-04 R11.

## Dependencies
- **Phase 01 first** — creates `isRejecting` + `clearWrongAttempt()` API consumed by 02 (no direct dep; visual reads existing `slotTile`) and 03 (calls `clearWrongAttempt()`).
- **Phase 02 + Phase 03 parallel after 01** — different files (`AnswerSlots.swift` vs `GameView.swift`); 02 = visual, 03 = driver. Both depend only on the state API from 01.
- **Phase 04 depends on all** — assertions exercise the full wrong flow end-to-end.

## Key Constraints (AGENTS.md)
- **Module `_pics1word`** (digit-prefixed); no `_` on new top-level Swift types. New `WrongFX` is `private` inside `AnswerSlots.swift` ⇒ no prefix concern.
- **`@MainActor` default isolation** (`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`): `PuzzleState`, `AnswerSlots`, `GameView` all MainActor; `Task { @MainActor in … }` driver is implicit but explicit annotation matches celebration style.
- **File-system synchronized groups** ⇒ drop new `.swift` files into `4pics1word/` / `4pics1wordTests/` — **no `project.pbxproj` edits** (test file in phase 04 auto-targets).
- **Swift Testing** for units: `import Testing`, `struct` + `@Test func`, `@testable import _pics1word`.
- **iOS 26.5 deployment target** ⇒ `KeyframeAnimator(initialValue:trigger:)` (iOS 18+) available. **Deviation (already hit by celebration):** trigger-variant has **no `repeatCount:` param** — don't pass one.
- **Reuse `accessibilityReduceMotion`** (`@Environment(\.accessibilityReduceMotion)`) — already wired in `AnswerSlots` L10 and `GameView` L17.
- **Reuse `.compositingGroup()`** above the red shadow (already on `base` at `AnswerSlots.swift:51`) — shadow on composited group renders once around tile silhouette; keeps glyph legible (no red `colorMultiply`).

## Decisions (locked via validation interview 2026-06-28)
1. **Shake scope → Row-only per-tile.** Per-tile `shakeX` keyframes inside `AnswerSlots` (mirrors celebration). Removes GameView's whole-screen `triggerShake()`/`shakeOffset` — word stays isolated as the error target.
2. **Timing → ~0.55s.** Glow 0.30s ∥ shake 0.36s; GameView defers clear by 550ms. Snappier than celebration (error, not reward).
3. **Haptic → Single error buzz.** One `Feedback.wrong()` (`.error` notification) at submission start. No per-tile rhythm (contrast with celebration's `celebrationTap` loop) — single buzz reads as a clean rejection.
4. **Reduce-motion → Skip FX, clear now.** Skip glow+shake AND skip the 550ms delay; call `clearWrongAttempt()` immediately. The clear is functional, not decorative.
5. **Red glow → `Color.red.opacity(0.85 * fx.glow)`, radius `14 * fx.glow`.** Mirrors locked-tile green convention (opacity scaling); strong, unambiguous error signal.
