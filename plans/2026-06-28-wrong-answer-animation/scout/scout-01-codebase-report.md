# Scout 01 — Codebase Report: Wrong-Answer Flow

## Context
Task: on wrong answer, do NOT dismiss word immediately. Play red glow → shake → then dismiss. Mirror the correct-word celebration pattern.

## §1 Current wrong-answer flow (the bug)
`PuzzleState.evaluate()` (`4pics1word/Game/PuzzleState.swift:171-186`):
```swift
private func evaluate() {
    if isSolved { ... } else {
        for index in tiles.indices {
            if tiles[index].slot != nil && !tiles[index].locked {
                let id = tiles[index].id
                tiles[index].slot = nil                       // ← tiles cleared SYNCHRONOUSLY
                if !bankOrder.contains(id) { bankOrder.append(id) }
            }
        }
        wrongAttemptToken &+= 1                               // ← token fires AFTER clear
    }
}
```
**Problem:** tiles return to bank in the same pass that bumps `wrongAttemptToken`. By the time `GameView.onChange(wrongAttemptToken)` fires the shake, `state.slotTile` is already empty ⇒ shake plays on an EMPTY row. No red glow exists.

## §2 Correct-word celebration pattern (the template to mirror)
HYBRID architecture (locked via validation interview, `plans/2026-06-28-correct-word-animation/plan.md`):
- **`PuzzleState.solvedToken: Int`** — UI trigger, bumped BEFORE deferred work, mirrors `wrongAttemptToken`.
- **`AppPhase.celebrating`** on `AppModel` — state semantic gating `.won` (2 consumers: `showGame`, `showWin`).
- **`AppModel.completeSolve()`** — explicit flip `.celebrating`→`.won`, called by GameView at wave-end. Safety-net Task (2.0s) guards missed calls.
- **`AnswerSlots`** self-observes `solvedToken` → per-tile `KeyframeAnimator` (scale+rotate+green-glow), L→R stagger via leading idle keyframe `index·0.08s`.
- **`GameView`** owns haptic Task (`Feedback.prepareCelebration()` → per-tile `celebrationTap()` → `celebrationChime()`) + completion (`onSolved()`).

## §3 Key files & line refs
| File | Role | Key lines |
|---|---|---|
| `4pics1word/Game/PuzzleState.swift` | engine, tiles, tokens | `evaluate()` 171-186; `wrongAttemptToken` 32; `solvedToken` 36; actions guard `phase == .playing` 109/119/127 |
| `4pics1word/Game/AppModel.swift` | app phase, deferred solve | `AppPhase` enum 4-9; `handleSolved` 62-80; `completeSolve` 84-89; safety-net Task 73-79 |
| `4pics1word/Components/AnswerSlots.swift` | slot row + celebration keyframes | `TileFX` VectorArithmetic 98-127; `keyframeAnimator` 62-90; `onChange(solvedToken)` 23-25; `ForEach(0..<slotCount, id:\.self)` 14 |
| `4pics1word/Views/GameView.swift` | screen, shake, wave driver | `shakeOffset` 13; `onChange(wrongAttemptToken)` 31-34 (shake+`Feedback.wrong()`); `triggerShake()` 150-156; wave Task 46-59 |
| `4pics1word/Game/Feedback.swift` | haptics | `wrong()` 19-22 (fresh `UINotificationFeedbackGenerator`); cached `notifyGen` 12; `prepareCelebration()` 33-36 |

## §4 Existing wrong-answer pieces (reusable)
- `wrongAttemptToken` already exists and is observed — reuse as the trigger (no new token needed).
- `GameView.triggerShake()` (L150) — whole-view shake via `shakeOffset`; 4 steps × 0.05s = 0.20s. Short. Could lengthen or move into AnswerSlots.
- `Feedback.wrong()` — `.error` notification haptic. Works.
- `TileFX` VectorArithmetic pattern in AnswerSlots — proven; a parallel `WrongFX` (glow + shakeX) fits cleanly.

## §5 Gating concern (the key design question)
During rejection animation the tiles must NOT be cleared yet, but `placeTile`/`removeTile`/hints all guard only on `phase == .playing`. `PuzzlePhase` is `.playing`/`.won` only (celebration deliberately left PuzzlePhase untouched). ⇒ Need an explicit guard during rejection.
Options:
- (a) `private(set) var isRejecting: Bool` on PuzzleState; guard all actions.
- (b) Add `PuzzlePhase.rejecting` — but pollutes the enum + invariant sweeps (`while phase != .won`).
Recommend (a): minimal, mirrors how `solvedToken` sits alongside `phase` without a new phase.

## §6 Celebration deviations to learn from
From `plan.md` §Verification: `repeatCount:1` param omitted (iOS26 trigger-variant has none); total-sleep hardcoded 320ms. `Feedback.win()` became dead code (moved into celebrationChime). Apply analogously: wrong haptic stays in `Feedback.wrong()`.

## §7 Test patterns (Swift Testing)
- Unit tests live in `4pics1wordTests/`, `import Testing`, `struct` + `@Test func`.
- `@testable import _pics1word` (module name has `_` prefix).
- Existing celebration tests: `AppModelCelebrationTests` (8 tests), `AppModelProgressLoopTests`. Mirror naming for wrong-attempt: e.g. `PuzzleStateWrongAttemptTests`.

## Unresolved questions
- Should the shake stay on GameView (whole-screen) or move to AnswerSlots (row-only)? Task says "shake the word" ⇒ row-only is more focused; but whole-screen is already wired. Planner to decide.
- Timing budget for wrong (celebration was 0.7-1.2s). Wrong should be snappier — propose ~0.5-0.6s.
- Reduce-motion path: skip glow+shake but STILL clear tiles (functional). Confirm.
