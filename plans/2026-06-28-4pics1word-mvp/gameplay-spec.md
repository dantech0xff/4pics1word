# Gameplay Spec — 4 Pics 1 Word

**This document is the source of truth for puzzle logic.** Every rule here is testable. Phase 3 (unit tests) must encode each invariant before any UI ships.

---

## 1. Data invariants (must hold for every level)

| # | Invariant | Enforced by |
|---|---|---|
| I1 | `solution.count` ∈ [3, 9] | data (verified: range 3–9) |
| I2 | Pool always contains the full multiset of `solution` letters | pool generator (construction) |
| I3 | Pool size = `max(12, solution.count + 3)` | pool generator |
| I4 | Pool order is deterministic for a given `puzzle.id` | seeded `SplitMix64` |
| I5 | At most one tile occupies any slot | `placeTile` picks first empty slot |
| I6 | `discarded == true` ⇒ `slot == nil` (removed tiles never occupy slots) | `removeHint` only touches bank tiles |
| I7 | `locked == true` ⇒ tile is in its correct slot & character == `solution[slot]` | `revealHint` only locks correct placements |
| I8 | The puzzle is always solvable from any reachable state (no dead-ends except won) | follows from I2 + I7 + hint rules below |

---

## 2. State model (single source of truth)

```swift
struct Tile: Identifiable, Equatable {
    let id: Int            // unique 0..<poolSize; never reused
    let character: Character
    var slot: Int?         // nil = in bank
    var locked: Bool       // true = hint-revealed, immutable & always correct
    var discarded: Bool    // true = removed by "Remove letters" hint, hidden
}

enum Phase { case playing, won }

@Observable
final class PuzzleState {
    let puzzle: Puzzle
    let solution: [Character]          // e.g. ['M','O','U','S','E']
    private(set) var tiles: [Tile]     // stable order; NEVER index by array pos — look up by id
    private(set) var bankOrder: [Int]  // tile ids, display order of bank
    var coins: Int
    private(set) var phase: Phase

    // derived (computed, never stored)
    var slotCount: Int { solution.count }
    var slotTile: [Tile?] { (0..<slotCount).map { idx in tiles.first { $0.slot == idx && !$0.discarded } } }
    var bankTiles: [Tile] { bankOrder.compactMap { id in tiles.first { $0.id == id && $0.slot == nil && !$0.discarded } } }
    var isFull: Bool { slotTile.allSatisfy { $0 != nil } }
    var isSolved: Bool { zip(slotTile, solution).allSatisfy { $0?.character == $1 } }
}
```

**Why `bankOrder` is separate from `tiles`:** lets `shuffle()` permute display without touching tile identity or slot state. Eliminates an entire class of "shuffle corrupted placements" bugs.

**Why look up by id, never array index:** `tiles` order is stable but the rule removes a whole bug family (mutating an array you're iterating, or assuming position == id).

---

## 3. Pool generation (deterministic)

```swift
func makePool(for puzzle: Puzzle) -> [Tile] {
    var rng = SplitMix64(seed: UInt64(bitPattern: Int64(truncatingIfNeeded: puzzle.id)))
    let sol = Array(puzzle.solution.uppercased())
    var chars: [Character] = sol                      // solution letters first (multiplicity preserved)
    let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
    while chars.count < max(12, sol.count + 3) {
        chars.append(alphabet.randomElement(using: &rng)!)   // distractors (may dup solution letters — that's fine)
    }
    chars.shuffle(using: &rng)                        // seeded → deterministic
    return chars.enumerated().map { (i, c) in
        Tile(id: i, character: c, slot: nil, locked: false, discarded: false)
    }
}
```

**I2 holds by construction**: solution letters are appended first; distractors only add. Distractors may duplicate solution letters (creates surplus copies — valid distractors).

```swift
struct SplitMix64: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
```

Public-domain PRNG. Swift's `SystemRandomNumberGenerator` is **not seedable** — don't use it for pools (breaks I4, breaks tests, breaks "same level = same scramble" expectation).

---

## 4. Player actions — exact algorithms

### 4.1 Place a letter (tap bank tile)
```
placeTile(id):
  guard phase == .playing
  guard tile(id).slot == nil && !discarded
  guard let firstEmpty = first index i in 0..<slotCount where slotTile[i] == nil
  set tile(id).slot = firstEmpty
  bankOrder.removeAll { $0 == id }
  if isFull { evaluate() }
```
If no empty slot (bank tile tapped when board full) → no-op.

### 4.2 Remove a letter (tap a filled, non-locked slot)
```
removeTile(id):
  guard phase == .playing
  guard tile(id).slot != nil && !tile(id).locked   // locked tiles are untouchable
  set tile(id).slot = nil
  if bankOrder does not contain id { bankOrder.append(id) }
  // removal can never cause a win → do NOT evaluate
```
Tapping an empty slot, or a locked slot, or a discarded tile → no-op.

### 4.3 Evaluate (auto-validate when board fills)
```
evaluate():
  if isSolved:
    phase = .won
    coins += reward(for: currentLevelIndex)        // tier-based, see §6
    progress.solvedIds.insert(puzzle.id)
    if currentLevelIndex < levels.count - 1 { progress.currentLevelIndex = currentLevelIndex + 1 }
    persist()
  else:
    // wrong: shake animation, then return ALL non-locked placed tiles to bank
    for each tile t where t.slot != nil && !t.locked:
        t.slot = nil
        bankOrder.append(t.id)     // if not already present
    trigger shake UI flag
```
**Locked tiles survive the wrong-answer clear** — that's the point of paying for Reveal.

### 4.4 Hint — Reveal a letter (cost: 60 coins)
```
revealHint():
  guard phase == .playing && coins >= 60
  guard let targetSlot = first i in 0..<slotCount where slotTile[i]?.character != solution[i]
      // i.e. empty OR wrong-letter slot — leftmost such
  let needed = solution[targetSlot]
  // free any wrong non-locked occupant of targetSlot
  if let occ = slotTile[targetSlot], !occ.locked:
      set tile(occ.id).slot = nil; bankOrder.append(occ.id)
  // pick a bank tile whose character == needed (guaranteed to exist — see proof P1)
  guard let pick = tiles.first { $0.slot == nil && !$0.discarded && $0.character == needed }
  set tile(pick.id).slot = targetSlot
  set tile(pick.id).locked = true
  coins -= 60
  bankOrder.removeAll { $0 == pick.id }
  if isFull { evaluate() }
```
**P1 (solvability of Reveal):** By I2 the pool has ≥ `countInSolution(needed)` tiles of `needed`. By I7 every locked tile is correctly placed, so no locked tile holds `needed` unless it's in a `needed`-slot (but targetSlot is wrong, so its needed char is not locked there). Therefore ≥1 `needed` tile is either in bank or in a non-locked wrong slot. We free wrong occupants first → a `needed` bank tile exists → `pick` is non-nil. ∎

### 4.5 Hint — Remove unused letters (cost: 90 coins)
```
removeHint():
  guard phase == .playing && coins >= 90
  // needed = multiset of solution letters over EMPTY slots only
  var needed: [Character: Int] = [:]
  for i in 0..<slotCount where slotTile[i] == nil:
      needed[solution[i], default: 0] += 1
  var kept: [Character: Int] = [:]
  for id in bankOrder:                              // iterate bank in display order
      let t = tile(id)
      if t.locked || t.discarded { continue }       // (bank tiles are never locked, but guard anyway)
      let c = t.character
      if (kept[c, default: 0]) < (needed[c, default: 0]):
          kept[c, default: 0] += 1                  // keep — needed for an empty slot
      else:
          set tile(id).discarded = true             // discard surplus/distractor
  coins -= 90
  bankOrder.removeAll { tile($0).discarded }
  // never auto-evaluate (Remove only hides tiles; board state unchanged)
```
**Effect:** bank reduces to exactly the letters needed to fill empty slots → puzzle becomes pure unscramble. Placed non-locked tiles are **untouched** (player may need to free a misplaced one manually — still solvable, see P2).

**P2 (solvability after Remove):** Empty-slot demand multiset is `needed`. After Remove, bank contains exactly `needed` (kept counts). Any letter needed but currently in a wrong non-locked slot: player taps that slot (§4.2) to return it to bank. Bank then has `needed` + freed letter; but Remove already kept one fewer of that char… revisit: Remove kept exactly `needed[c]` bank tiles of char `c`. If char `c` is needed (empty slot) but all `c` tiles were bank-resident, fine. If one `c` was misplaced in a wrong non-locked slot, then bank had `count(c)-1` available; Remove keeps `min(needed[c], available)` = `needed[c]` only if `available ≥ needed[c]`. If not, Remove keeps all available `c` and discards none → no over-discard. Player frees the misplaced `c` → bank now has `needed[c]`. Solvable. ∎

### 4.6 Hint — Shuffle (free)
```
shuffle():
  guard phase == .playing
  bankOrder.shuffle()       // system RNG, cosmetic, non-deterministic — that's fine
  // tiles array untouched → no slot/locked/discarded mutation → can't affect correctness
```

---

## 5. Disallowed / no-op cases (test each)

- Place when board full → no-op.
- Remove a locked tile → no-op.
- Remove a discarded tile → no-op.
- Reveal when board already correct → no-op (no targetSlot).
- Reveal when `coins < 60` → no-op, button disabled.
- Remove when `coins < 90` → no-op, button disabled.
- Any action when `phase == .won` → no-op.

---

## 6. Economy

- **Start coins:** 100 (enough for one Reveal + a bit more, forces budgeting).
- **Win reward:** `25 + 5 * tier`, where `tier = count of rateLevels entries ≤ currentLevelIndex`. (rateLevels from `strategy.json` = [27, 47, 67, …] → tiers ramp every ~20 levels.)
- **Costs:** Reveal 60 · Remove 90 · Shuffle 0.
- **Hint buttons disabled** when `coins < cost` (UI state, not just no-op).
- No "lose" state — no timer, no lives. Game is forever solvable.

---

## 7. Mandatory unit tests (Phase 3 gate — all must pass)

Located in `4pics1wordTests/` using Swift Testing (`import Testing`).

```
PoolSolvable:    ∀ level in first 50: generated pool contains solution multiset (I2)
                 ∀ level: pool.size == max(12, sol+3) (I3)
                 ∀ level: same seed → identical pool order (I4)

PlaceRemove:     place N distinct tiles → isFull; remove one → !isFull
                 place into full board → no-op
                 remove locked tile → no-op

WinDetection:    fill all slots correctly → phase == .won, coins increased
                 fill all slots with one wrong letter → phase stays .playing,
                     all non-locked tiles returned to bank, locked tiles stay
                 "BOOK" (dup O): place both O's in the two O slots + B + K → won

RevealHint:      on empty board → fills slot 0 with solution[0], locked
                 with one wrong placement at slot 0 → frees it, locks correct letter
                 never decreases solvability (post-reveal state still winnable)
                 coins decrement by 60; blocked when coins < 60

RemoveHint:      bank reduces to exactly empty-slot-needed multiset
                 placed non-locked tiles untouched
                 distractor tiles discarded
                 puzzle still solvable (player can finish)
                 coins decrement by 90; blocked when coins < 90

Shuffle:         bank order changes; no tile's slot/locked/discarded mutates

Regression:      "BOOK" full playthrough (dup letters)
                 "ICE" (3-letter, 9 distractors)
                 "OUTBOARD" (8-letter, ~4 distractors)
```

**Rule: no UI merges until these are green.** This is the correctness contract the user asked us not to break.

---

## 8. Open correctness risks (flag, don't hide)

1. **Distractor selection can't prevent alt-word solutions** (no offline dictionary). Acceptable — original game has the same property. Not a bug, a known limit.
2. **`evaluate()` clear-on-wrong is opinionated.** Original lets you self-correct without clearing. We chose clear-on-wrong for snappiness; reversible by removing the clear branch if playtest says otherwise. Pure product call, not a logic bug.
3. **`puzzle.id` may be negative or huge** (range includes values like `931816090`). `Int64(truncatingIfNeeded:)` + `UInt64(bitPattern:)` handles it. Don't cast to `UInt64` directly (negative ids would crash).
