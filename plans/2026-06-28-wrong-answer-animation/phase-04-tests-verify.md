# Phase 04 — Tests + Build + Manual QA

## Context Links
- Research (state-deferral): `research/researcher-02-state-deferral-report.md` §7
- Scout: `scout/scout-01-codebase-report.md` §7
- Mirror tests: `../2026-06-28-correct-word-animation/plan.md` §Verification
- Source: `4pics1word/Game/PuzzleState.swift`; `4pics1wordTests/`

## Overview
- Priority: P2. Status: Pending. Deps: Phases 01 + 02 + 03.
- Add `4pics1wordTests/PuzzleStateWrongAttemptTests.swift` (Swift Testing `@Suite struct` + `@Test func`). Mirror `AppModelCelebrationTests` style. Assertions from researcher-02 §7. Then `xcodebuild build` + `test`, then manual QA on Simulator.

## Key Insights
- **Swift Testing, not XCTest** (AGENTS.md): `import Testing`, `struct`-based suite, `@Test func`. `@testable import _pics1word` (module `_` prefix).
- **`evaluate()` is private** ⇒ tests trigger it indirectly by filling the board via `placeTile(lastTile)`. Last placement hits `if isFull { evaluate() }` (`PuzzleState.swift:114`).
- **File-system synchronized groups** ⇒ dropping the new `.swift` file into `4pics1wordTests/` auto-targets it. **No pbxproj edit.**
- **Assertion surface** (researcher-02 §7): deferred clear (tiles stay, flag set, token bumped); finisher (clears non-locked, preserves locked, resets flag); rejection gating (placeTile/revealHint/can* all no-op/false); idempotency; post-rejection solve regression.
- **No UI tests in this phase** — animation is visual; Simulator's haptics are silent by design (celebration plan §Verification flagged the same). Manual QA covers visual + interaction.
- **`Feedback.enabled`** is a static `var` — haptic tests not required (Feedback.wrong unchanged, proven).

## Requirements
- **R1** New file `4pics1wordTests/PuzzleStateWrongAttemptTests.swift`: `import Testing`, `@testable import _pics1word`, `@Suite struct PuzzleStateWrongAttemptTests`.
- **R2** Test `wrongEvaluate_doesNotClearTiles_setsFlag_bumpsToken`: fill board wrong via `placeTile`; assert all slots still non-nil, `state.isRejecting == true`, `state.wrongAttemptToken == 1`.
- **R3** Test `clearWrongAttempt_clearsNonLocked_preservesLocked_resetsFlag`: pre-lock one tile via `revealHint`, fill rest wrong, call `clearWrongAttempt()`; assert non-locked slots `nil` + ids in `bankOrder`; locked tile unchanged; `isRejecting == false`.
- **R4** Test `duringRejection_placeTile_isNoOp`: during rejection, `placeTile(bankId)`; assert that tile still `slot == nil`, `bankOrder` unchanged.
- **R5** Test `duringRejection_revealHint_isNoOp`: during rejection, `revealHint()`; assert no tile newly locked, coins unchanged.
- **R6** Test `duringRejection_canReveal_canRemove_canShuffle_allFalse`: during rejection (coins/surplus otherwise allow), assert all three compute `false`.
- **R7** Test `clearWrongAttempt_isIdempotent_secondCallNoOp`: call twice; assert second is a no-op (no extra state change, `isRejecting` stays `false`).
- **R8** Test `correctSolve_afterRejectionClear_works`: rejection → clear → fill correct → solve; assert `phase == .won`, `solvedToken == 1`.
- **R9** `xcodebuild -scheme 4pics1word build` succeeds.
- **R10** `xcodebuild -scheme 4pics1word test` succeeds (all new tests + existing green).
- **R11** Manual QA checklist (Simulator): (a) wrong submit shows red glow + simultaneous shake ~0.55s then clear; (b) rapid wrong submits don't deadlock; (c) hint buttons disable during rejection; (d) reduce-motion (Settings → Accessibility → Motion) ⇒ instant clear, no FX; (e) exit-to-home mid-rejection ⇒ fresh puzzle has no stuck tiles; (f) locked hint tile survives clear; (g) solve still triggers celebration wave.
- **N1** No UI tests added (animation is visual; existing `SolveFlowUITests` covers happy path).

## Architecture
```swift
import Testing
@testable import _pics1word

@Suite
struct PuzzleStateWrongAttemptTests {
    // Helper: build a state whose solution/pool guarantees a wrong fill is possible.
    private func makeWrongState(solution: String = "CAT", pool: [Character] = Array("BBB")) -> PuzzleState {
        PuzzleState(puzzle: Puzzle(id: 1, images: [], copyrights: [], solution: solution),
                    coins: 100,
                    pool: pool)
    }

    @Test
    func wrongEvaluate_doesNotClearTiles_setsFlag_bumpsToken() {
        let state = makeWrongState()
        // Fill all slots with wrong letters via placeTile (last place triggers evaluate).
        for id in state.bankTiles.map(\.id) {
            state.placeTile(id)
        }
        #expect(state.slotTile.allSatisfy { $0 != nil })      // tiles NOT cleared
        #expect(state.isRejecting == true)
        #expect(state.wrongAttemptToken == 1)
    }

    @Test
    func clearWrongAttempt_clearsNonLocked_preservesLocked_resetsFlag() {
        let state = makeWrongState()
        state.revealHint()                                    // lock one slot
        let lockedId = state.tiles.first(where: { $0.locked })?.id
        for id in state.bankTiles.map(\.id) { state.placeTile(id) }
        state.clearWrongAttempt()
        let nonLocked = state.tiles.filter { $0.slot != nil && !$0.locked }
        #expect(nonLocked.isEmpty)                            // non-locked cleared
        #expect(state.tiles.first { $0.id == lockedId }?.slot != nil)  // locked preserved
        #expect(state.isRejecting == false)
    }

    @Test
    func duringRejection_placeTile_isNoOp() {
        let state = makeWrongState()
        for id in state.bankTiles.map(\.id) { state.placeTile(id) }
        let bankIdBefore = state.bankTiles.first?.id
        state.placeTile(state.bankTiles.first?.id ?? -1)      // try place during rejection
        #expect(state.bankTiles.first?.id == bankIdBefore)
    }

    @Test
    func duringRejection_revealHint_isNoOp() {
        let state = makeWrongState()
        let coinsBefore = state.coins
        for id in state.bankTiles.map(\.id) { state.placeTile(id) }
        state.revealHint()
        #expect(state.coins == coinsBefore)                   // no coin charge
        #expect(state.tiles.filter { $0.locked }.count <= 1)  // no new lock beyond pre-existing
    }

    @Test
    func duringRejection_canReveal_canRemove_canShuffle_allFalse() {
        let state = makeWrongState()
        for id in state.bankTiles.map(\.id) { state.placeTile(id) }
        #expect(state.canReveal == false)
        #expect(state.canRemove == false)
        #expect(state.canShuffle == false)
    }

    @Test
    func clearWrongAttempt_isIdempotent_secondCallNoOp() {
        let state = makeWrongState()
        for id in state.bankTiles.map(\.id) { state.placeTile(id) }
        state.clearWrongAttempt()
        let snapshot = state.bankTiles.map(\.id)
        state.clearWrongAttempt()                              // second call
        #expect(state.bankTiles.map(\.id) == snapshot)
        #expect(state.isRejecting == false)
    }

    @Test
    func correctSolve_afterRejectionClear_works() {
        let state = makeWrongState(solution: "CAT", pool: Array("CAT"))
        // Force a wrong fill first: place a wrong tile, then clear via rejection.
        // (Construct a wrong board by placing from a pool that doesn't yet match —
        //  or place correct, then mutate to verify solve path post-clear.)
        for id in state.bankTiles.map(\.id) { state.placeTile(id) }
        if state.isRejecting { state.clearWrongAttempt() }
        for id in state.bankTiles.map(\.id) { state.placeTile(id) }  // correct fill
        #expect(state.phase == .won)
        #expect(state.solvedToken == 1)
    }
}
```
> NOTE: `Puzzle(...)` initializer above is illustrative — verify the real `Puzzle` init signature in `4pics1word/Game/Puzzle.swift` before finalizing helpers. Adjust `makeWrongState` to the actual constructor.

## Related Code Files
- **ADD** `4pics1wordTests/PuzzleStateWrongAttemptTests.swift` (new file, auto-targeted via synchronized group).
- **READ** `4pics1word/Game/Puzzle.swift` (confirm `Puzzle` init signature for the test helper).
- **READ** `4pics1wordTests/AppModelCelebrationTests.swift` (mirror style/assertion idioms).

## Implementation Steps
1. Read `4pics1word/Game/Puzzle.swift` + an existing test file to confirm idioms + `Puzzle` init.
2. Create `4pics1wordTests/PuzzleStateWrongAttemptTests.swift` with the `@Suite struct` + 7 `@Test` funcs (adjust `Puzzle(...)` init to actual signature).
3. Build for testing: `xcodebuild -project 4pics1word.xcodeproj -scheme 4pics1word -destination 'platform=iOS Simulator,name=iPhone 16' build-for-testing`.
4. Run tests: `xcodebuild ... test-without-building` (or `test`).
5. Iterate on failures (likely: `Puzzle` init args; locked-tile setup mechanics).
6. Manual QA on Simulator against R11 checklist.
7. Spot-check reduce-motion path (Settings toggled).

## Todo List
- [ ] `PuzzleStateWrongAttemptTests.swift` created with 7 `@Test` funcs
- [ ] Build-for-testing succeeds
- [ ] All 7 new tests pass
- [ ] Full test suite green (no regressions in `AppModelCelebrationTests` / `AppModelProgressLoopTests` / existing)
- [ ] Manual QA R11 (a)–(g) signed off
- [ ] Reduce-motion path verified on Simulator

## Success Criteria
- All 7 new `PuzzleStateWrongAttemptTests` pass.
- Existing tests unchanged in count and result (celebration, progress-loop, solve flow).
- Manual R11 checklist green; specifically: wrong ⇒ glow+shake (~0.55s) ⇒ clear; rapid wrongs don't deadlock; hint buttons disable during rejection; reduce-motion ⇒ instant clear; exit-to-home ⇒ no stuck tiles; locked hint survives; solve still celebrates.

## Risk Assessment
- **R-PuzzleInitMismatch (MED):** the `Puzzle(id:images:copyrights:solution:)` init in the test helper is illustrative; real signature may differ (e.g., `solutionCharacters`, asset refs). Mitigation: step 1 reads the actual init; adjust helper.
- **R-LockedTileSetup (LOW):** test R3 needs a locked tile pre-clear; `revealHint()` requires `canReveal` which depends on `hasUnrevealedSlot` — with all slots empty, the first `revealHint` locks slot 0. Verify before filling.
- **R-SimulatorHapticsSilent (LOW):** Simulator doesn't render haptics — manual QA can't verify `Feedback.wrong()` fires. Acceptable: haptic path is unchanged from prior verified behavior. Device QA optional.
- **R-TestFillSemantics (LOW):** filling "wrong" depends on the pool NOT matching the solution; `makeWrongState(solution:"CAT", pool:"BBB")` guarantees every placement is wrong. Verify `PoolFactory` isn't invoked (explicit `pool:` arg bypasses it).

## Security Considerations
- None. Tests + manual QA; no privileged operations.

## Next Steps
- Mark plan `status: implemented-verified` in `plan.md` once R9/R10/R11 green.
- Optional follow-up (out of scope): per-oscillation haptic taps if UX wants rhythmic error feedback (researcher-01 unresolved-Q recommended against).
