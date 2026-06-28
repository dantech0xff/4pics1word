# Phase 01 — Solve-Detection + Deferred `.won`

## Context Links
- Spec: `plans/2026-06-28-4pics1word-mvp/gameplay-spec.md` §4.3
- Scout: `scout/scout-01-codebase-report.md` §2,§3,§7
- Source: `PuzzleState.swift`, `AppModel.swift`, `AppRootView.swift`, `GameView.swift`

## Overview
- Priority: P2. Status: Pending.
- Break the fully-synchronous solve→sheet chain. Add `solvedToken` (PuzzleState) + `AppPhase.celebrating` (AppModel). `handleSolved` applies reward/persist synchronously but sets `.celebrating` (not `.won`). `completeSolve()` flips to `.won` (called by GameView wave-end OR reduce-motion shortcut). Sheet still keyed off `model.phase == .won` — unchanged.

## Key Insights
- `evaluate()` solve branch (PuzzleState L168-170) sets `state.phase=.won` + fires `onSolved`. **Keep** — PuzzleState-level `.won` is the engine truth (puzzle IS solved); tests + invariant-sweep depend on it.
- `handleSolved` (AppModel L54-65) is the ONLY setter of `model.phase=.won`. Defer just this.
- `wrongAttemptToken` (PuzzleState L32) is the proven observer pattern; `solvedToken` mirrors it 1:1.
- AppPhase consumed only in `AppRootView` `showGame` (L60) + `showWin` (L67). Adding `.celebrating` ⇒ update `showGame` get to include `.celebrating` (keep cover during wave). `showWin` unchanged.

## Requirements
- **R1** `solvedToken` increments EXACTLY once per solve, BEFORE `onSolved` fires (so GameView observer beats the synchronous handleSolved).
- **R2** `model.phase == .celebrating` does NOT present WinView. `showGame` stays true during `.celebrating`.
- **R3** `completeSolve()` is idempotent: safe to call when already `.won`/`.home`.
- **R4** Stored `celebrationTask` cancellable; `exitToHome()`/`nextLevel()`/`resetProgress()` cancel it.
- **R5** `Feedback.win()` removed from `WinView.onAppear` (moves to wave-end in Phase 03/04). WinView no longer self-fires haptic.
- **N1** No regressions: reward, persist, index-advance still happen at solve moment (not deferred) — never lose progress.

## Architecture
```
placeTile/revealHint → evaluate()
  ├─ solve branch: state.phase=.won; solvedToken&+=1; onSolved(self)
  │                                      ↓
  │   AppModel.handleSolved: reward+persist+advance; phase=.celebrating; store celebrationTask (safety-net sleep→completeSolve)
  │                                      ↓
  │   GameView.onChange(solvedToken): start wave (Phase 04) ── on done ──→ model.completeSolve()
  │   reduceMotion shortcut: model.completeSolve() immediately            ↓
  │                                                              phase=.won → showWin=true → sheet
  └─ wrong branch: (unchanged) wrongAttemptToken&+=1
```
Safety-net Task in handleSolved guards against GameView never calling `completeSolve()` (e.g. view dismissed mid-wave before observer wired). Wave-driver's explicit `completeSolve()` is the normal path.

## Related Code Files
- **MODIFY** `4pics1word/Game/PuzzleState.swift`
  - L32 area: add `private(set) var solvedToken: Int = 0` (+ doc comment mirroring L31).
  - L168-170 `evaluate()` solve branch: insert `solvedToken &+= 1` BEFORE `onSolved(self)`.
- **MODIFY** `4pics1word/Game/AppModel.swift`
  - L4-8 `AppPhase`: add `case celebrating` (between `playing`/`won`).
  - L17: add `private var celebrationTask: Task<Void, Never>?`.
  - L54-65 `handleSolved`: keep reward/persist/advance; change `phase = .won` (L64) → `phase = .celebrating`; start safety-net `celebrationTask = Task { try? await Task.sleep(for: .seconds(2.0)); guard !Task.isCancelled, self.phase == .celebrating else { return }; self.completeSolve() }`.
  - Add `func completeSolve() { celebrationTask?.cancel(); celebrationTask = nil; if phase == .celebrating { phase = .won } }`.
  - L67 `nextLevel`, L72 `exitToHome`, L82 `resetProgress`: prepend `celebrationTask?.cancel(); celebrationTask = nil`.
- **MODIFY** `4pics1word/Views/AppRootView.swift`
  - L60 `showGame` get: `model.phase == .playing || model.phase == .celebrating || model.phase == .won`.
- **MODIFY** `4pics1word/Views/WinView.swift`
  - L18: delete `.onAppear { Feedback.win() }` (haptic moves to wave-end).

## Implementation Steps
1. `PuzzleState`: add `solvedToken` property + increment in `evaluate()` solve branch (before `onSolved`).
2. `AppModel`: add `AppPhase.celebrating` case.
3. `AppModel`: add `celebrationTask` stored property + `completeSolve()` method.
4. `AppModel`: rewrite `handleSolved` tail — `.celebrating` + safety-net Task.
5. `AppModel`: cancel `celebrationTask` in `nextLevel`/`exitToHome`/`resetProgress`.
6. `AppRootView`: add `.celebrating` to `showGame` get.
7. `WinView`: remove `Feedback.win()` onAppear.
8. Build (`xcodebuild -project 4pics1word.xcodeproj -scheme 4pics1word -destination 'platform=iOS Simulator,name=iPhone 16' build`). Fix compile.

## Todo List
- [ ] `solvedToken` added + incremented pre-`onSolved`
- [ ] `AppPhase.celebrating` case added
- [ ] `completeSolve()` + `celebrationTask` in AppModel
- [ ] `handleSolved` sets `.celebrating`, starts safety-net Task
- [ ] cancel hooks in nextLevel/exitToHome/resetProgress
- [ ] `showGame` includes `.celebrating`
- [ ] `WinView` onAppear haptic removed
- [ ] Build green

## Success Criteria
- Solving a puzzle: `model.phase == .celebrating` immediately, `.won` only after `completeSolve()`.
- Sheet does NOT appear at `.celebrating`; appears only at `.won`.
- Reward/persist/index-advance unchanged (verify via existing progress tests after Phase 05 test update).
- `completeSolve()` idempotent; calling twice no-ops.
- Backgrounding mid-celebration then returning: safety-net Task (or re-entrant GameView observer) still reaches `.won`; no stuck state.

## Risk Assessment
- **R-TestBreak (HIGH):** `AppModelTests` L36-37 assert `model.phase == .won` synchronously → now `.celebrating`. Fix in Phase 05 (call `completeSolve()` in test then assert). Documented; expected.
- **R-Stuck (MED):** If GameView never calls `completeSolve()` (observer race), safety-net Task (2s) guarantees progress. Mitigation in place.
- **R-LostProgress (LOW):** Reward/persist stay synchronous ⇒ no progress loss even if celebration aborted.

## Security Considerations
- None. No auth, no network, no secrets. State machine change only.

## Next Steps
- → Phase 02 (tile modifier) + Phase 03 (haptics), parallel.
