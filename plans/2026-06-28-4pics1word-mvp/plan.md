# Implementation Plan — 4 Pics 1 Word MVP (offline)

**Scope:** 250 fully-image-backed levels (from `asset/core/strategy.json` ∩ `asset/puzzle/*.webp`), linear progression, 3 hints, local persistence. Realizes the design from the brainstorm session.

**Correctness contract:** [`gameplay-spec.md`](./gameplay-spec.md). Read it first — it is the source of truth for puzzle logic. **Phase 3 (unit tests) is a hard gate:** no UI work merges until every invariant in §7 of the spec passes.

**Honors `AGENTS.md`:**
- Target module is `_pics1word` (leading-digit gotcha). Only files whose name **is** the literal module name need the `_` prefix (e.g. `_pics1wordApp.swift`). Normal types like `GameView`, `Puzzle`, `LevelService` need **no** prefix — they just can't start with a digit.
- File-system synchronized groups are on → any `.swift`/resource dropped into `4pics1word/` is auto-targeted. **Do not edit `project.pbxproj`.**
- Default actor isolation is `MainActor`; `@Observable` view-models are fine as-is. Mark IO/non-UI work `nonisolated` only if profiler demands it.
- Unit tests use **Swift Testing** (`import Testing`, `struct` + `@Test`). UI tests use `XCTestCase`. Don't mix.

---

## Architecture (target tree)

```
4pics1word/
├── _pics1wordApp.swift            (exists — @main entry)
├── AppRootView.swift              NEW — phase router (NavigationStack)
├── Resources/                     NEW — bundle data (copied from ../asset)
│   ├── puzzles.json               (from asset/core/puzzles.json)
│   ├── strategy.json              (from asset/core/strategy.json)
│   └── PuzzleImages/              1000 webp (asset/puzzle/*.webp)
├── Data/
│   ├── Models.swift               Puzzle, Strategy, Progress (Codable)
│   ├── LevelService.swift         loads JSON, filters to image-backed, indexes 1…250
│   ├── SplitMix64.swift           seedable RNG (spec §3)
│   ├── PoolFactory.swift          makePool(for:) (spec §3)
│   └── ProgressStore.swift        UserDefaults + Codable wrapper
├── Game/
│   ├── PuzzleState.swift          @Observable engine (spec §2, §4) — THE LOGIC
│   ├── Economy.swift              reward/cost constants + tier calc (spec §6)
│   └── Audio.swift                optional, stub in v1
├── Views/
│   ├── SplashView.swift
│   ├── HomeView.swift
│   ├── GameView.swift             (slots, bank, hint bar)
│   ├── WinView.swift              (sheet)
│   ├── SettingsView.swift
│   └── CreditsView.swift          (stock-photo attributions — legal)
├── Components/
│   ├── PictureGrid.swift          2×2 webp image grid
│   ├── AnswerSlots.swift          N slots
│   ├── LetterBank.swift           12 tiles + shuffle
│   ├── TileButton.swift           single tile styling (default ButtonStyle)
│   └── CoinCounter.swift
└── Assets.xcassets                (exists — AppIcon, AccentColor)

4pics1wordTests/
├── _pics1wordTests.swift          (exists — replace example)
├── PoolFactoryTests.swift
├── PuzzleStatePlaceRemoveTests.swift
├── PuzzleStateWinTests.swift
├── PuzzleStateRevealTests.swift
├── PuzzleStateRemoveHintTests.swift
└── PuzzleStateShuffleTests.swift
```

Navigation (confirmed in brainstorm):
```
NavigationStack(path:) ← AppRootView
├── HomeView  ── push ──→ SettingsView ── push ──→ CreditsView
│            └── fullScreenCover(isPresented:) ──→ GameView
└── GameView  ── sheet(isPresented on phase==.won) ──→ WinView
                ├── "Next"  → reload GameView at progress.currentLevelIndex
                └── "Home"  → dismiss fullScreenCover
```
Drive off one `@Observable AppModel` holding `progress` + `phase: .home | .playing(idx) | .won`.

---

## Phases

### Phase 0 — Project setup & asset bundling  *(no logic)*
**Do:**
1. Create `4pics1word/Resources/`. Copy `asset/core/puzzles.json` + `asset/core/strategy.json` → `Resources/`. Copy `asset/puzzle/*.webp` → `Resources/PuzzleImages/`.
2. Add splash: set AppIcon from `asset/splash/appicon_splashscreen.png`; wire `asset/splash/background.png` as `LaunchScreen` background (Asset Catalog imageset, not the synchronized folder).
3. Keep root `asset/` as the canonical archive (do **not** delete — it's the source for future daily/mini/online work).

**Verify:** `xcodebuild build` succeeds; built `.app` contains `puzzles.json`, `strategy.json`, and all 1000 webp (check `find build -name '*.webp' | wc -l == 1000`).

**Gotcha:** Asset Catalog rejects webp imagesets reliably — load webp **by filename from the bundle**, not from the catalog:
```swift
func loadImage(_ puzzleId: Int, _ index: Int) -> Image {
    let name = "\(puzzleId)_\(index)"
    if let url = Bundle.main.url(forResource: name, withExtension: "webp"),
       let ui = UIImage(contentsOfFile: url) { Image(uiImage: ui) }
    else { Image(systemName: "photo") }   // fallback
}
```
Synchronized groups flatten subfolders, so `Bundle.main.url(forResource:withExtension:)` finds them at bundle root regardless of the `PuzzleImages/` source path.

---

### Phase 1 — Data layer  *(no UI)*
**Do:** Implement `Models.swift`, `LevelService.swift`, `SplitMix64.swift`, `PoolFactory.swift`, `ProgressStore.swift`.

**Key logic:**
- `LevelService.load()` decodes both JSONs, then **filters** `Strategy.orderedIds` to ids present in `Resources/PuzzleImages/` (by trying `Bundle.main.url(forResource: "\(id)_1", withExtension: "webp")`), and **re-indexes 1…250**. Players see "Level X / 250", never raw ids.
- `Puzzle.difficulty` is `String?` (only ~10% tagged; treat `nil` as normal).
- `Progress` = `{ currentLevelIndex: Int; coins: Int; solvedIds: Set<Int> }`, persisted via `ProgressStore` to `UserDefaults`.

**Verify (Swift Testing):**
- `LevelService` exposes 250 levels, indexed 0…249, in `strategy.json` order.
- Every level's image set (4 webp) loads.
- `PoolFactory` produces 12 tiles, contains solution multiset, deterministic per id.

**Exit gate:** tests pass.

---

### Phase 2 — Gameplay engine  *(the critical phase — spec §2, §4)*
**Do:** Implement `PuzzleState.swift` exactly per the spec. Methods: `placeTile`, `removeTile`, `evaluate` (private, called from place/reveal), `revealHint`, `removeHint`, `shuffle`. Expose only id-based lookups; never array-index `tiles`.

**Verify:** write the Phase 3 tests **in the same branch**, before merging. See gate below.

**Exit gate:** ⛔ **No UI (Phase 4+) merges until Phase 3 is green.** This is the user's explicit correctness requirement.

---

### Phase 3 — Correctness tests  *(hard gate)*
**Do:** Implement every test enumerated in `gameplay-spec.md §7`. Files split by concern (see tree). All use Swift Testing.

**Must-pass set (re-stated for prominence):**
- `PoolSolvable` — ∀ first 50 levels: pool has solution multiset, correct size, deterministic.
- `WinDetection` — correct fill wins; wrong fill clears non-locked tiles, keeps locked; duplicate-letter words (`BOOK`) win.
- `RevealHint` — fills/corrects leftmost wrong slot, locks it, frees prior wrong occupant, never desolvates, decrements coins, blocks when poor.
- `RemoveHint` — bank reduces to empty-slot-needed multiset; placed tiles untouched; still solvable; coins/`< 90` blocking.
- `Shuffle` — bank order changes; no tile state mutates.
- `Regression` — full playthroughs for `BOOK`, `ICE`, `OUTBOARD`.

**Run:**
```bash
xcodebuild -project 4pics1word.xcodeproj -scheme 4pics1word \
  -destination 'platform=iOS Simulator,name=iPhone 16' test
```

**Exit gate:** 100% of the above pass. Fix logic, not tests, on failure.

---

### Phase 4 — GameView UI  *(after gate)*
**Do:** `PictureGrid` (2×2 `LazyVGrid` of webp), `AnswerSlots` (HStack of slot tiles), `LetterBank` (`LazyVGrid`/`Flow`-ish of 12 `TileButton`s), hint bar (3 default `Button`s + coin counter). Default SwiftUI only — `ButtonStyle` for tiles, no custom drawing.

**Wiring:**
- Tap bank `TileButton` → `state.placeTile(id:)`.
- Tap filled non-locked `AnswerSlots` tile → `state.removeTile(id:)`.
- Hint buttons call `state.revealHint/removeHint/shuffle`; disabled when `coins < cost`.
- Observe `state.phase == .won` → present `WinView` (sheet).

**UX details:**
- Wrong-answer shake: observe a `wrongAttempt` flag → `.modifier` shake animation, then spec's auto-clear happens in `evaluate()`.
- Locked tiles: distinct style (e.g. accent-color background), untappable.

**Verify:** manual play on sim — solve 3 levels, use each hint, trigger a wrong answer. No state desync.

**Exit gate:** plays end-to-end on at least 5 levels incl. a duplicate-letter level.

---

### Phase 5 — Shell: navigation, Home, Win, Settings, Credits, Splash
**Do:** `AppRootView`, `HomeView` (Continue + Level X/250 + coins + Settings), `WinView` (word + coins earned + Next/Home), `SettingsView` (sound toggle, reset-progress with confirm), `CreditsView` (aggregated `copyrights` from solved levels), `SplashView` (1–2s branded intro → Home).

**Verify:**
- Cold launch shows splash → Home.
- Win → Next advances `currentLevelIndex` and persists; relaunch resumes correctly.
- Reset progress clears `Progress` and returns Home at Level 1.
- Credits lists attributions for played levels only (lazy-aggregate).

**Exit gate:** full session (cold start → solve 2 → kill app → relaunch → resume → reset) works.

---

### Phase 6 — Polish (optional, timebox)
Sound effects (correct/wrong/place) behind the Settings toggle. Haptic feedback (`UIImpactFeedbackGenerator`). App Store metadata + screenshots. Skip if shipping fast.

---

## Definition of done (MVP)
- [ ] 250 levels playable, linear, persistent.
- [ ] All `gameplay-spec.md §7` tests green.
- [ ] 3 hints work per spec; economy balanced enough not to softlock.
- [ ] Credits screen shows attributions.
- [ ] Cold-launch → splash → Home → play → win → next → relaunch resume works.
- [ ] `xcodebuild build` and `test` both pass on iPhone 16 sim.

---

## Risk register (carried from brainstorm, unresolved)
- **WebP in bundle** — verified iOS 14+ decodes natively via `UIImage(contentsOfFile:)`. If a specific webp fails to decode, fall back to `Image(systemName:"photo")` and log the id.
- **Coin softlock** — if a player spends all coins and can't solve, they're stuck (no earn mechanism beyond winning). Mitigation: Shuffle is free (always available), and wrong answers never cost coins. Acceptable for MVP; revisit if playtesting shows softlocks.
- **4,181 phantom levels** — `LevelService` filters them out. Never expose raw `puzzle.id` or "X / 4431" in UI.

## Open question for user (one only)
**`evaluate()` on wrong answer: auto-clear non-locked tiles (current spec) vs. let player self-correct?** The spec picks auto-clear for snappiness. This is reversible post-merge (one branch in `evaluate()`). Flag if you have a strong preference before Phase 4 ships.
