# Phase 05 — Tests + Manual Verify

## Context Links
- AGENTS.md (Swift Testing `import Testing`/`struct`+`@Test`; `@testable import _pics1word`)
- Affected tests: `4pics1wordTests/AppModelTests.swift`, `PuzzleStateTests.swift`, `PuzzleStateHintTests.swift`

## Overview
- Priority: P2. Status: Pending. Deps: Phases 01–04.
- Update broken `AppModelTests` (model.phase now `.celebrating` post-solve). Add Swift Testing tests for `solvedToken` + `completeSolve()` idempotency + `.celebrating`→`.won` transition. No real haptics/animation in tests (Simulator-safe, deterministic). Manual QA checklist for device (haptics) + reduce-motion + edge cases.

## Key Insights
- **Only `model.phase == .won` assertions break** (AppModelTests L36-37). PuzzleState-level `state.phase == .won` stays TRUE (Phase 01 keeps engine truth) ⇒ `PuzzleStateWinTests`, `PuzzleStateHintTests`, invariant-sweep UNAFFECTED.
- Swift Testing style: `@MainActor @Suite(.serialized) struct X { @Test func y() {} }` — match existing files.
- Animation/haptics are UI/runtime side-effects ⇒ NOT unit-tested. Verify manually + via reduce-motion shortcut path (which IS testable: `completeSolve()` called synchronously).
- `Task.sleep` in `completeSolve` safety-net makes timing non-deterministic ⇒ tests call `completeSolve()` SYNCHRONOUSLY (bypass Task) to assert `.won`.

## Requirements
- **R1** `AppModelTests.solvingLastLevelWrapsToFirst` + `solvingMidLevelAdvancesByOne`: after placing last tile, assert `model.phase == .celebrating`, then call `model.completeSolve()`, then assert `model.phase == .won` + existing index/number asserts.
- **R2** New test: `solvedToken` increments exactly once on solve (PuzzleState). Mirror `wrongAttemptToken` test style.
- **R3** New test: `completeSolve()` idempotent — calling twice leaves `.won`, no crash, no double-advance.
- **R4** New test: `completeSolve()` when `.home`/`.playing` is a no-op (doesn't flip to `.won`).
- **R5** New test: reward/persist/index-advance happen at solve moment (BEFORE `completeSolve`) — assert `lastReward`/`progress.coins`/`currentLevelIndex` correct while still `.celebrating`.
- **R6** `xcodebuild test` green on `4pics1word` scheme (iPhone 16 sim).
- **R7** Manual QA checklist executed (device for haptics).

## Architecture (test shape)
```
@Test func solveFlipsToCelebratingThenWon() {
    let model = AppModel(); model.continueGame()
    guard let state = model.gameState else { Issue.record(...); return }
    for c in state.puzzle.solution { placeChar(state, c) }
    #expect(state.phase == .won)               // engine truth unchanged
    #expect(model.phase == .celebrating)       // NEW — deferred
    #expect(state.solvedToken == 1)            // NEW
    model.completeSolve()
    #expect(model.phase == .won)               // sheet-ready
}
@Test func completeSolveIdempotent() { ... completeSolve(); completeSolve(); #expect(model.phase == .won) }
@Test func completeSolveNoOpWhenHome() { let m = AppModel(); m.completeSolve(); #expect(m.phase == .home) }
@Test func rewardAppliedBeforeCompleteSolve() { ...; #expect(model.lastReward > 0); #expect(model.phase == .celebrating) }
```

## Related Code Files
- **MODIFY** `4pics1wordTests/AppModelTests.swift`
  - L36-37 area: change assertion block → `.celebrating` then `completeSolve()` then `.won`. Apply to both `solvingLastLevelWrapsToFirst` (L20) + `solvingMidLevelAdvancesByOne` (L44).
- **MODIFY** `4pics1wordTests/PuzzleStateTests.swift` (or new file `PuzzleStateSolveTokenTests.swift`)
  - Add `solvedToken` increments-once test in `PuzzleStateWinTests` suite.
- **CREATE** `4pics1wordTests/AppModelCelebrationTests.swift` (optional new suite) — idempotency + no-op-when-home + reward-before-completeSolve. (File-system synchronized group ⇒ auto-target, no pbxproj edit.)
- **NO CHANGE** `PuzzleStateHintTests.swift` (invariant sweep `while state.phase != .won` still valid — PuzzleState.phase unchanged).

## Implementation Steps
1. Update `AppModelTests` two tests: `.celebrating` → `completeSolve()` → `.won`.
2. Add `solvedToken==1` assertion to `PuzzleStateWinTests.correctFillWinsAndFiresOnSolved`.
3. Create `AppModelCelebrationTests.swift`: idempotency, no-op-when-home, reward-before-completeSolve.
4. Run `xcodebuild -project 4pics1word.xcodeproj -scheme 4pics1word -destination 'platform=iOS Simulator,name=iPhone 16' test`.
5. Fix any fallout. Re-run until green.
6. Execute Manual QA checklist below.

## Todo List
- [ ] AppModelTests updated (2 tests)
- [ ] solvedToken assertion added to PuzzleStateWinTests
- [ ] AppModelCelebrationTests.swift created (3 tests)
- [ ] `xcodebuild test` green
- [ ] Manual QA checklist (below) executed + signed off

## Success Criteria
- All Swift Testing tests green; no regressions in unaffected suites (PuzzleStateHintTests invariant sweep passes).
- Manual QA: celebration visible + haptics felt on device; reduce-motion skips cleanly; no orphan sheet on background/dismiss/new-puzzle.

## Manual QA Checklist (device = iPhone with Taptic Engine)
- [ ] Solve normally → tiles wave L→R (scale+rotate+green glow), per-tile haptic tap, final chime, sheet slides up ~1s later.
- [ ] Solve via Reveal hint (locked tiles present) → locked tiles also animate (Q5 default).
- [ ] Settings → Accessibility → Reduce Motion ON → solve → NO wave, sheet immediate.
- [ ] Settings → Haptics OFF (app) → solve → no haptic, wave still plays.
- [ ] Background app mid-wave → return → sheet appears (no orphan / no stuck).
- [ ] Tap Home (onExit) mid-wave → no sheet pops after returning to Home.
- [ ] Solve last level → wrap to level 1 works (Next from WinView).
- [ ] iPad → silent haptics (expected), wave plays.
- [ ] Multiple rapid solves (Next→solve→Next) → no wave bleed/overlap.

## Risk Assessment
- **R-FlakyTaskTest (MED):** do NOT assert timing/`Task.sleep` outcomes in tests (non-deterministic on CI/Simulator). Tests use synchronous `completeSolve()` only. Documented.
- **R-HiddenTestBreak (LOW):** grep confirms only AppModelTests L36-37 assert `model.phase == .won` post-solve. PuzzleState assertions unaffected. If other suites surface, update analogously.

## Security Considerations
- None.

## Next Steps
- Ship. Optional follow-ups (YAGNI-deferred): `PhaseAnimator` alt if KeyframeAnimator feels heavy; CoreHaptics crescendo pattern if `.light` taps feel flat; asset-catalog color symbols for green (project has none yet).
