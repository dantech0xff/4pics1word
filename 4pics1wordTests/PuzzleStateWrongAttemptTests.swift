import Testing
import Foundation
@testable import _pics1word

// MARK: - Test helpers (local; mirror PuzzleStateTests idioms, real Puzzle init)

private func makePuzzle(_ solution: String, id: Int = 1) -> Puzzle {
    Puzzle(id: id, solution: solution, copyrights: [], time: 1, rating: 1.0, difficulty: nil)
}

private func makeWrongState(solution: String = "CAT", pool: String = "BBB", coins: Int = 1000) -> PuzzleState {
    PuzzleState(puzzle: makePuzzle(solution), coins: coins, pool: Array(pool))
}

private func placeChar(_ state: PuzzleState, _ c: Character) {
    guard let tile = state.bankTiles.first(where: { $0.character == c }) else {
        Issue.record("No bank tile available for character \(c)")
        return
    }
    state.placeTile(tile.id)
}

// MARK: - Wrong-answer deferred-clear contract

@MainActor @Suite(.serialized)
struct PuzzleStateWrongAttemptTests {

    @Test
    func wrongEvaluate_doesNotClearTiles_setsFlag_bumpsToken() {
        let state = makeWrongState(solution: "CAT", pool: "BBB")
        // Pool "BBB" guarantees every placement is wrong against solution "CAT".
        for c in "BBB" { placeChar(state, c) }   // last place triggers evaluate()
        // Deferred clear: tiles stay populated, flag set, token bumped.
        #expect(state.isFull, "Tiles must stay populated during rejection")
        #expect(state.isRejecting == true)
        #expect(state.wrongAttemptToken == 1)
        #expect(state.phase == .playing)
    }

    @Test
    func clearWrongAttempt_clearsNonLocked_preservesLocked_resetsFlag() {
        let state = makeWrongState(solution: "CAT", pool: "CBB", coins: 1000)
        state.revealHint()                        // locks slot 0 with the correct 'C'
        let lockedId = state.tiles.first { $0.locked }?.id
        #expect(state.slotTile[0]?.character == "C")
        #expect(state.slotTile[0]?.locked == true)
        // Fill remaining slots with wrong letters (B in slot 1, B in slot 2).
        for c in "BB" { placeChar(state, c) }     // board full → wrong → deferred
        #expect(state.isRejecting == true)
        state.clearWrongAttempt()
        // Non-locked slots cleared.
        let stillSlotted = state.tiles.filter { $0.slot != nil }
        #expect(stillSlotted.count == 1, "Only the locked tile remains slotted")
        // Locked tile preserved.
        #expect(state.tiles.first { $0.id == lockedId }?.slot != nil)
        #expect(state.tiles.first { $0.id == lockedId }?.locked == true)
        // Non-locked ids back in bank.
        #expect(state.bankTiles.contains(where: { $0.character == "B" }))
        #expect(state.isRejecting == false)
    }

    @Test
    func duringRejection_removeTile_isNoOp() {
        // Rejection only fires on a FULL board. During rejection the board is full of
        // slotted tiles ⇒ `placeTile` is a no-op anyway (no empty slot). The mutation the
        // canMutate gate actually blocks here is `removeTile` (a slotted-tile tap). Without
        // the gate, removeTile would pull a non-locked tile back to the bank mid-animation.
        let state = makeWrongState(solution: "CAT", pool: "BBB")
        for c in "BBB" { placeChar(state, c) }
        #expect(state.isRejecting == true)
        #expect(state.isFull, "Premise: rejection holds a full board")
        let slotsBefore = state.slotTile.map { $0?.id }
        let bankBefore = state.bankTiles.map(\.id)
        guard let slottedId = state.slotTile.compactMap({ $0?.id }).first else {
            Issue.record("Premise failed: full board must have a slotted tile")
            return
        }
        state.removeTile(slottedId)   // valid non-locked slotted tile — must no-op via canMutate
        #expect(state.slotTile.map { $0?.id } == slotsBefore)
        #expect(state.bankTiles.map(\.id) == bankBefore)
        #expect(state.isRejecting == true)
    }

    @Test
    func duringRejection_placeTile_isNoOp() {
        // placeTile is structurally a no-op during rejection (board full ⇒ no empty slot).
        // This test documents that contract directly; the load-bearing gate for the
        // frozen-board invariant is removeTile (see test above).
        let state = makeWrongState(solution: "CAT", pool: "BBBBBB")
        for c in "BBB" { placeChar(state, c) }
        #expect(state.isRejecting == true)
        let slotsBefore = state.slotTile.map { $0?.id }
        let bankBefore = state.bankTiles.map(\.id)
        guard let liveBankId = state.bankTiles.first?.id else {
            Issue.record("Premise failed: bank must be non-empty")
            return
        }
        state.placeTile(liveBankId)   // valid bank tile — board full + canMutate both block it
        #expect(state.slotTile.map { $0?.id } == slotsBefore)
        #expect(state.bankTiles.map(\.id) == bankBefore)
        #expect(state.isRejecting == true)
    }

    @Test
    func duringRejection_revealHint_isNoOp() {
        // Pool contains the needed 'C' so revealHint would SUCCEED without the gate
        // (find slot 0 needs C, pick C, lock it, charge coins). Gate must block it.
        let state = makeWrongState(solution: "CAT", pool: "CATBBB", coins: 1000)
        let coinsBefore = state.coins
        let lockedCountBefore = state.tiles.filter { $0.locked }.count
        // Force a wrong fill first (B into all three slots), leaving C in the bank.
        for c in "BBB" { placeChar(state, c) }
        #expect(state.isRejecting == true)
        #expect(state.bankTiles.contains(where: { $0.character == "C" }), "Premise: C is in bank")
        state.revealHint()
        #expect(state.coins == coinsBefore, "No coin charge during rejection (canMutate gate)")
        #expect(state.tiles.filter { $0.locked }.count == lockedCountBefore, "No new lock")
    }

    @Test
    func duringRejection_canReveal_canRemove_canShuffle_allFalse() {
        // Surplus pool makes canRemove (surplus>0) and canShuffle (bankOrder.count>1)
        // load-bearing: without canMutate they'd be TRUE; the gate forces them FALSE.
        let state = makeWrongState(solution: "CAT", pool: "BBBBBB", coins: 1000)
        for c in "BBB" { placeChar(state, c) }   // 3 slots filled wrong, 3 B's remain in bank
        #expect(state.isRejecting == true)
        #expect(state.surplusBankCount > 0, "Premise: surplus exists so canRemove would be true")
        #expect(state.bankOrder.count > 1, "Premise: bank has >1 tile so canShuffle would be true")
        // All three are FALSE only because canMutate == false during rejection.
        #expect(state.canReveal == false)
        #expect(state.canRemove == false)
        #expect(state.canShuffle == false)
    }

    @Test
    func clearWrongAttempt_isIdempotent_secondCallNoOp() {
        let state = makeWrongState(solution: "CAT", pool: "BBB")
        for c in "BBB" { placeChar(state, c) }
        state.clearWrongAttempt()
        #expect(state.isRejecting == false)
        let snapshotSlots = state.slotTile.map { $0?.id }
        let snapshotBank = state.bankTiles.map(\.id)
        // Second call must be a no-op (guard isRejecting short-circuits).
        state.clearWrongAttempt()
        #expect(state.slotTile.map { $0?.id } == snapshotSlots)
        #expect(state.bankTiles.map(\.id) == snapshotBank)
        #expect(state.isRejecting == false)
    }

    @Test
    func correctSolve_afterRejectionClear_works() {
        // Solution "CAT"; pool "CATABC" allows a wrong fill first, then the correct fill.
        let state = makeWrongState(solution: "CAT", pool: "CATABC", coins: 1000)
        // Wrong attempt: B→slot0, A→slot1, C→slot2 (slot0 needs C, slot2 needs T) ⇒ wrong.
        placeChar(state, "B")
        placeChar(state, "A")
        placeChar(state, "C")
        #expect(state.isRejecting == true)
        state.clearWrongAttempt()
        #expect(state.isRejecting == false)
        // Correct fill: C, A, T.
        placeChar(state, "C")
        placeChar(state, "A")
        placeChar(state, "T")
        #expect(state.phase == .won)
        #expect(state.solvedToken == 1)
    }
}
