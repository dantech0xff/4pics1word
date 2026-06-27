import Foundation
import Observation

struct Tile: Identifiable, Equatable, Hashable {
    let id: Int
    let character: Character
    var slot: Int?
    var locked: Bool = false
    var discarded: Bool = false
}

enum PuzzlePhase: Equatable {
    case playing
    case won
}

/// Single source of truth for one puzzle attempt. See plans/.../gameplay-spec.md §2, §4.
/// Invariants (enforced here, verified in tests):
///   I5  at most one tile per slot
///   I6  discarded ⇒ slot == nil
///   I7  locked ⇒ slot is correct & character == solution[slot]
@Observable
final class PuzzleState {
    let puzzle: Puzzle
    let solution: [Character]
    private(set) var tiles: [Tile]          // id-ascending; NEVER reordered (shuffle touches bankOrder only)
    private(set) var bankOrder: [Int]       // tile ids in bank-display order
    var coins: Int
    private(set) var phase: PuzzlePhase = .playing

    /// Increments on each full-but-wrong clear. UI observes to trigger shake animation.
    private(set) var wrongAttemptToken: Int = 0

    /// Fired once when the puzzle is solved. AppModel applies reward + persists + advances.
    var onSolved: (PuzzleState) -> Void = { _ in }

    init(puzzle: Puzzle, coins: Int, pool: [Character], onSolved: @escaping (PuzzleState) -> Void = { _ in }) {
        self.puzzle = puzzle
        self.solution = puzzle.solutionCharacters
        self.coins = coins
        self.onSolved = onSolved
        let built: [Tile] = pool.enumerated().map { Tile(id: $0.offset, character: $0.element) }
        self.tiles = built
        self.bankOrder = built.map(\.id)
    }

    convenience init(puzzle: Puzzle, coins: Int, onSolved: @escaping (PuzzleState) -> Void = { _ in }) {
        self.init(puzzle: puzzle, coins: coins, pool: PoolFactory.makePool(for: puzzle), onSolved: onSolved)
    }

    // MARK: - Derived state

    var slotCount: Int { solution.count }

    var slotTile: [Tile?] {
        (0..<slotCount).map { idx in tiles.first { $0.slot == idx && !$0.discarded } }
    }

    var bankTiles: [Tile] {
        bankOrder.compactMap { id in tiles.first { $0.id == id && $0.slot == nil && !$0.discarded } }
    }

    var isFull: Bool { slotTile.allSatisfy { $0 != nil } }

    var isSolved: Bool { zip(slotTile, solution).allSatisfy { $0?.character == $1 } }

    // MARK: - Hint availability (read-only, for UI button state)

    var hasUnrevealedSlot: Bool {
        (0..<slotCount).contains { slotTile[$0]?.character != solution[$0] }
    }

    var surplusBankCount: Int {
        var needed: [Character: Int] = [:]
        for i in 0..<slotCount where slotTile[i] == nil { needed[solution[i], default: 0] += 1 }
        var kept: [Character: Int] = [:]
        var surplus = 0
        for tile in bankTiles {
            if kept[tile.character, default: 0] < needed[tile.character, default: 0] {
                kept[tile.character, default: 0] += 1
            } else {
                surplus += 1
            }
        }
        return surplus
    }

    var canReveal: Bool { phase == .playing && coins >= HintCost.reveal && hasUnrevealedSlot }
    var canRemove: Bool { phase == .playing && coins >= HintCost.remove && surplusBankCount > 0 }
    var canShuffle: Bool { phase == .playing && bankOrder.count > 1 }

    // MARK: - Tile lookup (by id, never array position)

    func tile(_ id: Int) -> Tile? { tiles.first { $0.id == id } }

    private func mutateTile(_ id: Int, _ body: (inout Tile) -> Void) {
        guard let index = tiles.firstIndex(where: { $0.id == id }) else { return }
        body(&tiles[index])
    }

    // MARK: - Actions (spec §4)

    /// Tap a bank tile → fill the first empty slot. Validates when board fills.
    func placeTile(_ id: Int) {
        guard phase == .playing else { return }
        guard let t = tile(id), t.slot == nil, !t.discarded else { return }
        guard let firstEmpty = (0..<slotCount).first(where: { slotTile[$0] == nil }) else { return }
        mutateTile(id) { $0.slot = firstEmpty }
        bankOrder.removeAll { $0 == id }
        if isFull { evaluate() }
    }

    /// Tap a filled, non-locked slot → return tile to bank. Never triggers evaluate.
    func removeTile(_ id: Int) {
        guard phase == .playing else { return }
        guard let t = tile(id), t.slot != nil, !t.locked, !t.discarded else { return }
        mutateTile(id) { $0.slot = nil }
        if !bankOrder.contains(id) { bankOrder.append(id) }
    }

    /// Reveal one correct letter (leftmost wrong/empty slot), lock it. (spec §4.4)
    func revealHint() {
        guard canReveal else { return }
        guard let targetSlot = (0..<slotCount).first(where: { slotTile[$0]?.character != solution[$0] }) else { return }
        let needed = solution[targetSlot]
        if let occupant = slotTile[targetSlot], !occupant.locked {
            mutateTile(occupant.id) { $0.slot = nil }
            if !bankOrder.contains(occupant.id) { bankOrder.append(occupant.id) }
        }
        guard let pick = tiles.first(where: { $0.slot == nil && !$0.discarded && $0.character == needed }) else { return }
        mutateTile(pick.id) { $0.slot = targetSlot; $0.locked = true }
        bankOrder.removeAll { $0 == pick.id }
        coins -= HintCost.reveal
        if isFull { evaluate() }
    }

    /// Discard bank tiles not needed to fill empty slots. (spec §4.5)
    func removeHint() {
        guard canRemove else { return }
        var needed: [Character: Int] = [:]
        for i in 0..<slotCount where slotTile[i] == nil { needed[solution[i], default: 0] += 1 }
        var kept: [Character: Int] = [:]
        var toDiscard: [Int] = []
        for id in bankOrder {
            guard let t = tile(id), t.slot == nil, !t.locked, !t.discarded else { continue }
            let c = t.character
            if kept[c, default: 0] < needed[c, default: 0] {
                kept[c, default: 0] += 1
            } else {
                toDiscard.append(id)
            }
        }
        for id in toDiscard { mutateTile(id) { $0.discarded = true } }
        bankOrder.removeAll { toDiscard.contains($0) }
        coins -= HintCost.remove
    }

    /// Reshuffle bank display order. Cosmetic; never mutates tile state. (spec §4.6)
    func shuffle() {
        guard canShuffle else { return }
        bankOrder.shuffle()
    }

    /// Auto-validate when the board is full. (spec §4.3)
    /// On solve: fire onSolved (AppModel applies reward + persists). AppModel owns coin reward,
    /// not PuzzleState — keeps the engine free of tier/level-index knowledge.
    private func evaluate() {
        if isSolved {
            phase = .won
            onSolved(self)
        } else {
            for index in tiles.indices {
                if tiles[index].slot != nil && !tiles[index].locked {
                    let id = tiles[index].id
                    tiles[index].slot = nil
                    if !bankOrder.contains(id) { bankOrder.append(id) }
                }
            }
            wrongAttemptToken &+= 1
        }
    }
}
