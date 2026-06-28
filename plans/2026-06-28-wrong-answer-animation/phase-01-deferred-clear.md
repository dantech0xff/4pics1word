# Phase 01 — Deferred Clear in PuzzleState

## Context Links
- Research (state-deferral): `research/researcher-02-state-deferral-report.md` §1, §2, §5, §6
- Scout: `scout/scout-01-codebase-report.md` §1, §3, §5
- Mirror plan: `../2026-06-28-correct-word-animation/plan.md` (HYBRID pattern)
- Source: `4pics1word/Game/PuzzleState.swift`

## Overview
- Priority: P2. Status: Pending. Deps: none (foundational state API).
- Split `evaluate()` wrong branch: stop clearing tiles inline; instead set `isRejecting=true`, bump `wrongAttemptToken`. Add `clearWrongAttempt()` finisher (idempotent) + DRY `canMutate` computed prop gating all tile/hint mutations. Locked hints preserved.

## Key Insights
- **Today's bug (`PuzzleState.swift:177-184`):** tile-clear loop runs in the same pass that bumps `wrongAttemptToken`. By the time `onChange(wrongAttemptToken)` fires, `slotTile` is already empty ⇒ any post-token animation plays on an empty row.
- **Idempotent finisher (`guard isRejecting`):** lets GameView's primary driver AND any speculative safety call both invoke `clearWrongAttempt()` without races. No safety-net Task is needed (researcher-02 §3) — the gate self-clears.
- **DRY `canMutate`** collapses `phase == .playing` literals in `placeTile`/`removeTile`/`canReveal`/`canRemove`/`canShuffle` into one edit point. Hint buttons bind `.disabled(!enabled)` to `can*` ⇒ they auto-disable during rejection without view changes (`GameView.swift:145`).
- **Order matters:** `isRejecting = true` BEFORE `wrongAttemptToken &+= 1`. By the time `onChange` fires, the flag is set. `@MainActor` default isolation serializes anyway ⇒ race-free.
- **No new PuzzlePhase:** adding `.rejecting` would force sweeps of every `phase == .playing` site + WinView gating for zero capability (YAGNI). Bool flag is the minimal mirror of how `solvedToken` sits alongside `phase` (researcher-02 §6).
- **Locked hint preservation:** `&& !tiles[index].locked` predicate copied verbatim from old clear loop (invariant I7).

## Requirements
- **R1** Wrong `evaluate()` sets `isRejecting=true` then bumps `wrongAttemptToken`; does NOT clear tiles.
- **R2** `clearWrongAttempt()` runs the existing clear loop (non-locked slotted tiles → bank), then sets `isRejecting=false`.
- **R3** `clearWrongAttempt()` is idempotent: `guard isRejecting else { return }` ⇒ second call no-ops.
- **R4** `clearWrongAttempt()` preserves locked tiles (`!tiles[index].locked` predicate kept).
- **R5** `private(set) var isRejecting: Bool = false` added near `wrongAttemptToken` (L32).
- **R6** `private var canMutate: Bool { phase == .playing && !isRejecting }` gates: `placeTile` (L109), `removeTile` (L119), `canReveal` (L92), `canRemove` (L93), `canShuffle` (L94).
- **R7** Solve branch of `evaluate()` untouched.
- **N1** No new PuzzlePhase enum case. No new public token (`wrongAttemptToken` reused).
- **N2** `revealHint`/`removeHint`/`shuffle` bodies need NO change — they early-return on `can*` which is now `canMutate`-derived.

## Architecture
```swift
// Near wrongAttemptToken (PuzzleState.swift:32):
private(set) var wrongAttemptToken: Int = 0
private(set) var isRejecting: Bool = false

// DRY gate (add above the Hint availability section, ~L91):
private var canMutate: Bool { phase == .playing && !isRejecting }

// Rewrite computed props (L92-94):
var canReveal: Bool { canMutate && coins >= HintCost.reveal && hasUnrevealedSlot }
var canRemove: Bool { canMutate && coins >= HintCost.remove && surplusBankCount > 0 }
var canShuffle: Bool { canMutate && bankOrder.count > 1 }

// Rewrite action guards (L109, L119):
func placeTile(_ id: Int) {
    guard canMutate else { return }
    // … body unchanged …
}
func removeTile(_ id: Int) {
    guard canMutate else { return }
    // … body unchanged …
}

// Rewrite evaluate() (L171-186):
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

// New finisher (add below evaluate(), ~L187):
/// GameView calls this AFTER glow+shake finishes (or immediately under reduce-motion).
/// Re-derives the clear set from current tile state ⇒ idempotent if invoked twice.
/// Flips isRejecting=false at end.
func clearWrongAttempt() {
    guard isRejecting else { return }
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

## Related Code Files
- **MODIFY** `4pics1word/Game/PuzzleState.swift`
  - L32: add `private(set) var isRejecting: Bool = false` directly below `wrongAttemptToken`.
  - L92-94: rewrite `canReveal`/`canRemove`/`canShuffle` to use `canMutate` (add the private computed prop just above, ~L91).
  - L109: `placeTile` guard `phase == .playing` → `canMutate`.
  - L119: `removeTile` guard `phase == .playing` → `canMutate`.
  - L176-185 (`evaluate()` else branch): replace clear-loop with `isRejecting = true; wrongAttemptToken &+= 1`.
  - After L186: add `func clearWrongAttempt()`.

## Implementation Steps
1. Add `private(set) var isRejecting: Bool = false` under `wrongAttemptToken` (L32).
2. Add `private var canMutate: Bool { phase == .playing && !isRejecting }` (~L91).
3. Rewrite `canReveal`/`canRemove`/`canShuffle` (L92-94) over `canMutate`.
4. Swap guards in `placeTile` (L109) and `removeTile` (L119) to `canMutate`.
5. Replace wrong branch of `evaluate()` (L176-185) with `isRejecting = true; wrongAttemptToken &+= 1`.
6. Append `clearWrongAttempt()` after `evaluate()`.
7. Build green (won't visually do anything yet — driver lands in phase 03).

## Todo List
- [ ] `isRejecting` property added
- [ ] `canMutate` computed prop added
- [ ] `canReveal`/`canRemove`/`canShuffle` rewritten over `canMutate`
- [ ] `placeTile`/`removeTile` guards swapped
- [ ] `evaluate()` wrong branch defers clear
- [ ] `clearWrongAttempt()` finisher added
- [ ] Build succeeds (`xcodebuild … build`)

## Success Criteria
- Submitting a wrong word leaves `slotTile` populated; `state.isRejecting == true`; `state.wrongAttemptToken` increments by 1.
- `state.clearWrongAttempt()` returns all non-locked slotted tiles to `bankOrder`; locked tiles unchanged; `isRejecting == false`.
- Calling `clearWrongAttempt()` twice is a no-op the second time.
- During rejection: `placeTile`/`removeTile`/`revealHint`/`removeHint`/`shuffle` are all no-ops; `canReveal`/`canRemove`/`canShuffle` evaluate to `false`.
- Existing solve path unaffected (solve branch unchanged).

## Risk Assessment
- **R-StuckRejecting (MED):** if GameView never calls `clearWrongAttempt()` (e.g., phase 03 driver bug), puzzle freezes — `canMutate == false` blocks all input. Mitigation: phase 03 wires the driver; phase 04 tests cover the deferred-clear invariant. Idempotency makes a defensive extra call safe.
- **R-TestFillPath (LOW):** unit tests fill the board via `placeTile`; once rejection lands, the test sequence must call `clearWrongAttempt()` between wrong attempts. Mitigation: phase 04 test (a) covers the post-rejection happy path.
- **R-EnumLeak (LOW):** no enum case added ⇒ zero sweep risk across `phase == .playing` sites. Confirmed by §6 of researcher-02.

## Security Considerations
- None. Pure engine state; no I/O, no untrusted input, no crypto.

## Next Steps
- → Phase 02 (parallel after 01): `AnswerSlots` WrongFX visual.
- → Phase 03 (parallel after 01): GameView `wrongTask` driver calling `clearWrongAttempt()`.
