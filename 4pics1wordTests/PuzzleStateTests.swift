import Testing
import Foundation
@testable import _pics1word

// MARK: - Test helpers

private func makePuzzle(_ solution: String, id: Int = 1) -> Puzzle {
    Puzzle(id: id, solution: solution, copyrights: [], time: 1, rating: 1.0, difficulty: nil)
}

private func makeState(_ solution: String, pool: String, coins: Int = 1000) -> PuzzleState {
    PuzzleState(puzzle: makePuzzle(solution), coins: coins, pool: Array(pool))
}

private func placeChar(_ state: PuzzleState, _ c: Character) {
    guard let tile = state.bankTiles.first(where: { $0.character == c }) else {
        Issue.record("No bank tile available for character \(c)")
        return
    }
    state.placeTile(tile.id)
}

private func activeChars(_ state: PuzzleState) -> [Character] {
    state.tiles.filter { !$0.discarded }.map(\.character)
}

// MARK: - Place / Remove

@MainActor @Suite(.serialized)
struct PuzzleStatePlaceRemoveTests {
    @Test
    func placeFillsFirstEmptyThenIsFull() {
        let state = makeState("ICE", pool: "ICEXYZABCDEF")
        #expect(state.slotCount == 3)
        #expect(!state.isFull)
        placeChar(state, "I")
        placeChar(state, "C")
        #expect(!state.isFull)
        placeChar(state, "E")
        #expect(state.isFull)
    }

    @Test
    func removeMakesRoom() {
        let state = makeState("ICE", pool: "ICEXYZABCDEF")
        placeChar(state, "I")
        placeChar(state, "C")  // do NOT place E — a full correct board wins and locks out removal
        #expect(!state.isFull)
        // remove the C tile (slot 1)
        let cTile = state.slotTile[1]!
        state.removeTile(cTile.id)
        #expect(state.slotTile[1] == nil)
        #expect(state.bankTiles.contains(where: { $0.id == cTile.id }))
    }

    @Test
    func removeTileOnBankTileIsNoOp() {
        let state = makeState("ICE", pool: "ICEXYZABCDEF")
        let bankId = state.bankTiles.first!.id
        state.removeTile(bankId)  // tile has slot == nil
        #expect(state.tile(bankId)?.slot == nil)
        #expect(state.bankTiles.count == 12)
    }

    @Test
    func placeAfterWonIsNoOp() {
        let state = makeState("ICE", pool: "ICEXYZABCDEF")
        placeChar(state, "I"); placeChar(state, "C"); placeChar(state, "E")
        #expect(state.phase == .won)
        let bankId = state.bankTiles.first?.id
        if let id = bankId { state.placeTile(id) }  // phase guard blocks
        #expect(state.phase == .won)
    }
}

// MARK: - Win detection

@MainActor @Suite(.serialized)
struct PuzzleStateWinTests {
    @Test
    func correctFillWinsAndFiresOnSolved() {
        let state = makeState("MOUSE", pool: "MOUSEAXYZBCD")
        var solvedPuzzleId: Int?
        state.onSolved = { solvedPuzzleId = $0.puzzle.id }
        #expect(state.phase == .playing)
        #expect(state.solvedToken == 0)
        for c in "MOUSE" { placeChar(state, c) }
        #expect(state.phase == .won)
        #expect(state.solvedToken == 1, "solvedToken must increment exactly once on solve")
        #expect(solvedPuzzleId == state.puzzle.id)
    }

    @Test
    func wrongFillClearsNonLockedAndStaysPlaying() {
        let state = makeState("MOUSE", pool: "MOUSEAXYZBCD")
        // Place a wrong letter (A) in slot 0, then O U S E in 1..4
        placeChar(state, "A")  // slot 0 (wrong, needs M)
        placeChar(state, "O")
        placeChar(state, "U")
        placeChar(state, "S")
        placeChar(state, "E")
        // The 5th placement fills the board; evaluate() runs immediately, sees it's wrong,
        // and auto-clears all non-locked tiles (spec §4.3). So the board is NOT full anymore.
        #expect(!state.isFull)
        #expect(state.phase == .playing)           // not won
        #expect(state.wrongAttemptToken == 1)
        #expect(state.slotTile.allSatisfy { $0 == nil }, "All non-locked tiles returned to bank")
        #expect(state.bankTiles.count == 12, "All tiles back in bank")
    }

    @Test
    func lockedTileSurvivesWrongClear() {
        let state = makeState("MOUSE", pool: "MOUSEAXYZBCD", coins: 1000)
        state.revealHint()  // locks slot 0 with M (the correct letter)
        #expect(state.slotTile[0]?.character == "M")
        #expect(state.slotTile[0]?.locked == true)
        // Fill remaining slots with wrong letters
        placeChar(state, "A")  // slot 1 (wrong, needs O)
        placeChar(state, "X")  // slot 2 (wrong)
        placeChar(state, "Y")  // slot 3 (wrong)
        placeChar(state, "Z")  // slot 4 (wrong) → board full → evaluate → wrong → clear non-locked
        #expect(!state.isFull)                      // slots 1-4 cleared by auto-evaluate
        #expect(state.phase == .playing)
        // Locked slot 0 survives
        #expect(state.slotTile[0]?.character == "M")
        #expect(state.slotTile[0]?.locked == true)
        // Other slots cleared
        #expect(state.slotTile[1] == nil)
        #expect(state.slotTile[2] == nil)
        #expect(state.slotTile[3] == nil)
        #expect(state.slotTile[4] == nil)
    }

    @Test
    func duplicateLettersBookWins() {
        // BOOK needs two O tiles
        let state = makeState("BOOK", pool: "BOOKAXYZABCD")
        for c in "BOOK" { placeChar(state, c) }
        #expect(state.phase == .won)
    }

    @Test
    func regressionIce() {
        let puzzle = makePuzzle("ICE")
        let state = PuzzleState(puzzle: puzzle, coins: 1000)  // real PoolFactory pool
        for c in "ICE" { placeChar(state, c) }
        #expect(state.phase == .won)
    }

    @Test
    func regressionOutboardWithDuplicateO() {
        let puzzle = makePuzzle("OUTBOARD")  // contains two O's
        let state = PuzzleState(puzzle: puzzle, coins: 1000)
        for c in "OUTBOARD" { placeChar(state, c) }
        #expect(state.phase == .won)
    }

    @Test
    func regressionBookFromRealPool() {
        let puzzle = makePuzzle("BOOK")
        let state = PuzzleState(puzzle: puzzle, coins: 1000)
        for c in "BOOK" { placeChar(state, c) }
        #expect(state.phase == .won)
    }
}
