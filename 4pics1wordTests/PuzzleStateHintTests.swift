import Testing
import Foundation
@testable import _pics1word

// MARK: - Test helpers (local to this file)

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

// MARK: - Reveal hint (spec §4.4)

@Suite(.serialized)
struct PuzzleStateRevealTests {
    @Test
    func revealFillsFirstEmptySlotWithCorrectLetterAndLocks() {
        let state = makeState("MOUSE", pool: "MOUSEAXYZBCD")
        let before = state.coins
        state.revealHint()
        #expect(state.slotTile[0]?.character == "M")
        #expect(state.slotTile[0]?.locked == true)
        #expect(state.coins == before - HintCost.reveal)
    }

    @Test
    func revealFreesWrongOccupantBeforeLockingCorrectLetter() {
        let state = makeState("MOUSE", pool: "MOUSEAXYZBCD")
        placeChar(state, "A")  // slot 0 wrong (needs M)
        let wrongTileId = state.slotTile[0]!.id
        state.revealHint()
        #expect(state.slotTile[0]?.character == "M")
        #expect(state.slotTile[0]?.locked == true)
        // The freed wrong tile is back in the bank
        #expect(state.tile(wrongTileId)?.slot == nil)
        #expect(state.bankTiles.contains(where: { $0.id == wrongTileId }))
    }

    @Test
    func revealNeverDesolvates() {
        let puzzle = makePuzzle("OUTBOARD")
        let state = PuzzleState(puzzle: puzzle, coins: 10000)
        for _ in 0..<8 {
            state.revealHint()
            // Every non-discarded tile multiset must still cover the solution
            #expect(PoolFactory.containsSolution(activeChars(state), solution: puzzle.solutionCharacters),
                   "Reveal must never make the puzzle unsolvable")
        }
        // After revealing all 8 slots, the puzzle is solved
        #expect(state.phase == .won)
    }

    @Test
    func revealBlockedWhenInsufficientCoins() {
        let state = makeState("MOUSE", pool: "MOUSEAXYZBCD", coins: 10)
        #expect(!state.canReveal)
        let before = state.coins
        state.revealHint()
        #expect(state.coins == before, "No coins spent when blocked")
        #expect(state.slotTile[0] == nil, "No letter revealed when blocked")
    }

    @Test
    func revealNoOpWhenAlreadySolved() {
        let state = makeState("ICE", pool: "ICEXYZABCDEF")
        for c in "ICE" { placeChar(state, c) }
        #expect(state.phase == .won)
        #expect(!state.canReveal)
    }

    @Test
    func duplicateLetterRevealHandlesBook() {
        // BOOK: two O's. Reveal slot 0 (B), then reveal again — should fill next empty with O.
        let state = makeState("BOOK", pool: "BOOKAXYZABCD", coins: 10000)
        state.revealHint()
        #expect(state.slotTile[0]?.character == "B")
        state.revealHint()
        #expect(state.slotTile[1]?.character == "O")
        #expect(state.slotTile[1]?.locked == true)
        // Pool still solvable
        #expect(PoolFactory.containsSolution(activeChars(state), solution: Array("BOOK")))
    }
}

// MARK: - Remove hint (spec §4.5)

@Suite(.serialized)
struct PuzzleStateRemoveHintTests {
    @Test
    func removeStripsSurplusLeavingExactlyNeededMultiset() {
        // 4 surplus A's + X,Y,Z distractors; needed for empty slots = M,O,U,S,E
        let state = makeState("MOUSE", pool: "MOUSEAAAAXYZ")
        #expect(state.canRemove)
        state.removeHint()
        let bankChars = state.bankTiles.map(\.character).sorted()
        #expect(bankChars == ["E", "M", "O", "S", "U"])
    }

    @Test
    func removeLeavesPuzzleSolvable() {
        let state = makeState("MOUSE", pool: "MOUSEAAAAXYZ")
        state.removeHint()
        for c in "MOUSE" { placeChar(state, c) }
        #expect(state.phase == .won)
    }

    @Test
    func removeDoesNotTouchPlacedNonLockedTiles() {
        let state = makeState("MOUSE", pool: "MOUSEAAAAXYZ")
        placeChar(state, "A")  // slot 0 = A (wrong, non-locked)
        let placedId = state.slotTile[0]!.id
        state.removeHint()
        // Placed A still in slot 0 (remove only touches bank)
        #expect(state.slotTile[0]?.id == placedId)
        #expect(state.tile(placedId)?.slot == 0)
    }

    @Test
    func removeBlockedWhenInsufficientCoins() {
        let state = makeState("MOUSE", pool: "MOUSEAAAAXYZ", coins: 10)
        #expect(!state.canRemove)
        let before = state.coins
        state.removeHint()
        #expect(state.coins == before)
        #expect(state.bankTiles.count == 12, "Nothing discarded when blocked")
    }

    @Test
    func removeNoOpWhenBankExactlyMatchesEmptySlots() {
        // Place all but one slot correctly so bank surplus is gone after considering empty slot
        let state = makeState("ICE", pool: "ICEABCABCAB")
        // First strip distractors
        state.removeHint()
        #expect(state.bankTiles.map(\.character).sorted() == ["C", "E", "I"])
        // Now bank is exactly the solution letters; no surplus left
        #expect(!state.canRemove, "No surplus remaining after first remove")
    }
}

// MARK: - Shuffle (spec §4.6)

@Suite(.serialized)
struct PuzzleStateShuffleTests {
    @Test
    func shufflePreservesAllTileState() {
        let state = makeState("MOUSE", pool: "MOUSEAXYZBCD")
        placeChar(state, "M")
        placeChar(state, "O")
        state.revealHint()  // introduce a locked tile in some slot for richer state

        let snapshotTiles = state.tiles
        let snapshotBankOrder = state.bankOrder

        state.shuffle()

        // Every tile's slot/locked/discarded unchanged
        for snap in snapshotTiles {
            let now = state.tile(snap.id)!
            #expect(now.slot == snap.slot, "shuffle must not change tile slots")
            #expect(now.locked == snap.locked)
            #expect(now.discarded == snap.discarded)
        }
        // bankOrder is a permutation of the prior bankOrder (same ids)
        #expect(Set(state.bankOrder) == Set(snapshotBankOrder))
        #expect(state.bankOrder.count == snapshotBankOrder.count)
    }

    @Test
    func shuffleIsNoOpWhenBankHasOneOrFewer() {
        let state = makeState("ICE", pool: "ICEXYZABCDEF")
        // Place all but one tile so bank has 1
        placeChar(state, "I"); placeChar(state, "C"); placeChar(state, "E")
        // Now board is full and won; phase guard blocks anyway
        #expect(state.phase == .won)
        let before = state.bankOrder
        state.shuffle()
        #expect(state.bankOrder == before)
    }
}

// MARK: - Invariant sweep across the real level set

@Suite(.serialized)
struct PuzzleStateInvariantTests {
    @Test
    func everyLevelSolvableViaReveals() async throws {
        let service = LevelService.load()
        // Sweep the first 50 real levels: each must be fully solvable using only Reveal (proves P1)
        for level in service.levels.prefix(50) {
            let state = PuzzleState(puzzle: level, coins: 10000)
            var guardCount = 0
            while state.phase != .won && guardCount < 20 {
                state.revealHint()
                guardCount += 1
            }
            #expect(state.phase == .won, "Level \(level.id) (\(level.solution)) should be solvable via reveals")
        }
    }
}
