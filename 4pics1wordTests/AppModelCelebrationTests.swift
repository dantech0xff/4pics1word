import Testing
import Foundation
@testable import _pics1word

// MARK: - Local helpers (file-private)

private func placeChar(_ state: PuzzleState, _ c: Character) {
    guard let tile = state.bankTiles.first(where: { $0.character == c }) else {
        Issue.record("No bank tile available for character \(c)")
        return
    }
    state.placeTile(tile.id)
}

// MARK: - Celebration lifecycle (Phase 01: AppPhase.celebrating + completeSolve)

@MainActor @Suite(.serialized)
struct AppModelCelebrationTests {
    @Test
    func completeSolveFlipsCelebratingToWon() {
        let model = AppModel()
        model.continueGame()
        guard let state = model.gameState else {
            Issue.record("gameState should be set after continueGame()")
            return
        }
        for c in state.puzzle.solution { placeChar(state, c) }

        // Engine truth: solved. App phase: deferred to .celebrating.
        #expect(state.phase == .won)
        #expect(model.phase == .celebrating)

        model.completeSolve()
        #expect(model.phase == .won, "completeSolve() must flip .celebrating → .won")
    }

    @Test
    func completeSolveIsIdempotent() {
        let model = AppModel()
        model.continueGame()
        guard let state = model.gameState else {
            Issue.record("gameState should be set after continueGame()")
            return
        }
        for c in state.puzzle.solution { placeChar(state, c) }
        #expect(model.phase == .celebrating)

        model.completeSolve()
        let indexAfterFirst = model.progress.currentLevelIndex
        let coinsAfterFirst = model.progress.coins
        let rewardAfterFirst = model.lastReward
        #expect(model.phase == .won)

        // Second call must be a no-op: no crash, no double-advance, no phase regression.
        model.completeSolve()
        #expect(model.phase == .won)
        #expect(model.progress.currentLevelIndex == indexAfterFirst, "Idempotent: index not advanced twice")
        #expect(model.progress.coins == coinsAfterFirst, "Idempotent: coins not double-credited")
        #expect(model.lastReward == rewardAfterFirst)
    }

    @Test
    func completeSolveNoOpWhenHome() {
        let model = AppModel()
        // Fresh model: phase == .home. completeSolve() must NOT flip to .won.
        #expect(model.phase == .home)
        model.completeSolve()
        #expect(model.phase == .home, "completeSolve() is a no-op when not .celebrating")
    }

    @Test
    func completeSolveNoOpWhenPlaying() {
        let model = AppModel()
        model.continueGame()
        #expect(model.phase == .playing)
        model.completeSolve()
        #expect(model.phase == .playing, "completeSolve() is a no-op mid-game (.playing)")
    }

    @Test
    func rewardAppliedBeforeCompleteSolve() {
        let model = AppModel()
        model.continueGame()
        guard let state = model.gameState else {
            Issue.record("gameState should be set after continueGame()")
            return
        }
        let coinsBefore = model.progress.coins
        let indexBefore = model.progress.currentLevelIndex
        for c in state.puzzle.solution { placeChar(state, c) }

        // Reward/persist/index-advance happen synchronously at solve moment (Phase 01 R5/N1),
        // BEFORE completeSolve() flips the phase. Guards against progress-loss regressions.
        #expect(model.phase == .celebrating, "Still celebrating")
        #expect(model.lastReward > 0, "Reward applied at solve moment, not deferred")
        #expect(model.progress.coins == coinsBefore + model.lastReward, "Coins credited at solve moment")
        #expect(model.progress.currentLevelIndex != indexBefore || model.totalLevels == 1,
                "Index advanced at solve moment")
        #expect(model.progress.solvedIds.contains(state.puzzle.id), "Puzzle id persisted at solve moment")
    }

    @Test
    func exitToHomeCancelsCelebration() {
        let model = AppModel()
        model.continueGame()
        guard let state = model.gameState else {
            Issue.record("gameState should be set after continueGame()")
            return
        }
        for c in state.puzzle.solution { placeChar(state, c) }
        #expect(model.phase == .celebrating)

        // User dismisses mid-celebration → exitToHome cancels safety-net Task + clears state.
        model.exitToHome()
        #expect(model.phase == .home)
        #expect(model.gameState == nil)

        // Calling completeSolve now must NOT resurrect .won (no orphan sheet).
        model.completeSolve()
        #expect(model.phase == .home, "Cleared celebration must not resurrect .won")
    }

    @Test
    func nextLevelCancelsCelebrationAndStartsFresh() {
        let model = AppModel()
        model.continueGame()
        guard let state = model.gameState else {
            Issue.record("gameState should be set after continueGame()")
            return
        }
        for c in state.puzzle.solution { placeChar(state, c) }
        #expect(model.phase == .celebrating)

        // Jumping straight to next puzzle mid-celebration must work cleanly.
        model.nextLevel()
        #expect(model.phase == .playing, "nextLevel resets to .playing")
        #expect(model.gameState != nil)
        #expect(model.gameState?.puzzle.id != state.puzzle.id, "New puzzle loaded")
    }

    @Test
    func resetProgressCancelsCelebration() {
        let model = AppModel()
        model.continueGame()
        guard let state = model.gameState else {
            Issue.record("gameState should be set after continueGame()")
            return
        }
        for c in state.puzzle.solution { placeChar(state, c) }
        #expect(model.phase == .celebrating)

        model.resetProgress()
        #expect(model.phase == .home)
        #expect(model.gameState == nil)
        #expect(model.progress.solvedIds.isEmpty, "Reset clears solved ids")
    }
}
