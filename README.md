# 4 Pics 1 Word

Single-player iOS word game built in **SwiftUI**. Four pictures share one word — arrange the scrambled letter bank into the answer slots to solve. Earn coins per solve and via a 7-day daily check-in streak; spend coins on hints.

Fully offline, no third-party dependencies (no SPM packages), no backend.

- **App target:** `4pics1word` · **Bundle ID:** `org.1588e22dda3a7db8.-pics1word` (iPhone + iPad)
- **Language/UI:** Swift + SwiftUI (declarative; only `UIImage` touches UIKit)
- **Toolchain:** Xcode 26.6 · **Deployment target:** iOS 26.5+
- **State:** Swift `@Observable` (Observation) — no Combine
- **Persistence:** `UserDefaults` (JSON-encoded `Progress` / `Settings`)

---

## Architecture pattern

A **single-`@Observable`-model + declarative view tree** architecture. There is no VIPER/MVVM-C scaffolding, no dependency container, no Combine — just Observation-driven views reading mutable models, with one app-wide orchestrator.

### State ownership

| Owner | Holds | Role |
|---|---|---|
| `AppRootView` | `@State AppModel` | App-wide orchestrator (progress, settings, phase, active puzzle). |
| `GameView` | `let state: PuzzleState` | One puzzle attempt (bank, slots, solve/reject tokens). |
| `CheckInView` | `let model: AppModel` | Reads/writes streak via `model.checkIn()`; ephemeral UI local. |

- **`AppModel` is `@Observable`** — any view that holds it re-renders on mutation automatically (no `@Published`, no `sink`). Child views receive the model (or a per-puzzle `PuzzleState`) via `let` + SwiftUI value tracking.
- **`AppPhase`** (`home` / `playing` / `celebrating` / `won`) is the single source of truth for which root layer is on screen.
- **Solve reward + persistence + level advance live in `AppModel`, not `PuzzleState`** — keeps the puzzle engine free of tier/level/economy knowledge. `PuzzleState` only owns tile mechanics and fires `onSolved`.

### Navigation shell

Sheet/cover-based flow — no `NavigationStack` for the game itself:
```
SplashView (1.5s) → NavigationStack { HomeView }
                                       └─ settings / credits (push)
                     ├─ fullScreenCover → GameView  (phase ∈ playing/celebrating/won)
                     │      └─ sheet → WinView      (phase == .won)
                     └─ sheet(.medium) → CheckInView — daily reward; auto-fires once/day
```

### Solve lifecycle (cross-component)
```
board full → PuzzleState.evaluate() → onSolved(state)
   → AppModel.handleSolved: reward + persist + advance index + phase = .celebrating
GameView observes state.solvedToken → per-tile celebration wave + haptics
   → wave end → AppModel.completeSolve() → phase = .won → WinView sheet
```
Wrong path: `evaluate()` sets `isRejecting` + bumps `wrongAttemptToken` → `AnswerSlots` plays red glow/shake; `GameView` clears tiles via `clearWrongAttempt()` after 550ms (immediately under reduce-motion).

### Key subsystems
- **Daily check-in / streak** (`CheckIn`): rewards `[20,25,30,35,40,50,100]` indexed by `(streakDays-1) % 7`; day-7 jackpot; clock-rewind protection (120s tolerance).
- **Puzzle / level / pool** (`LevelService` + `PoolFactory` + `SplitMix64`): bundled `puzzles.json`/`strategy.json` + `.webp` images; decoys seeded by `SplitMix64(puzzle.id.stableSeed)` → deterministic pool per puzzle; seamless level wrap-around.
- **Economy** (`Economy`): `startingCoins = 100`; solve reward `25 + 5*tier`; hint costs reveal 60 / remove 90 / shuffle 0.
- **Feedback** (`Feedback`): UIKit haptics only (no audio); cached generators.

### Why no Combine / no layering?
YAGNI + KISS. The app is offline, single-user, single-window. Observation gives granular re-renders without boilerplate; a flat model + value-passed `PuzzleState` is easier to test (89 unit tests drive `PuzzleState`/`AppModel`/`CheckIn` in isolation) than a deep VIPER stack.

> Deeper detail: [`docs/system-architecture.md`](./docs/system-architecture.md) (incl. Mermaid view+state tree), [`docs/codebase-summary.md`](./docs/codebase-summary.md) (file-by-file).

---

## Project structure

```
4pics1word/
├── 4pics1word/
│   ├── _pics1wordApp.swift        # @main entry; hosts AppRootView; -uitest-reset hook
│   ├── Views/                     # AppRootView, HomeView, GameView, CheckInView, WinView, …
│   ├── Components/                # LetterBank, PictureGrid, AnswerSlots, TileButton, …
│   ├── Game/                      # AppModel, PuzzleState, CheckIn, Economy, Feedback, Settings
│   └── Data/                      # LevelService, Models, PoolFactory, ProgressStore, SplitMix64
├── 4pics1wordTests/               # Swift Testing (import Testing) — unit
├── 4pics1wordUITests/             # XCTest — UI
├── docs/                          # architecture, roadmap, standards, deploy, …
└── 4pics1word.xcodeproj
```

**Module-name gotcha:** the Swift module is `_pics1word`, not `4pics1word` (identifiers can't start with a digit — Xcode prefixes source files with `_`). Unit tests import it as `@testable import _pics1word`.

---

## Setup

### Prerequisites
- **Xcode 26.6+** (needs the iOS 26.5 SDK — a recent toolchain is required).
- **File-system synchronized groups are ON** — any `.swift` file added to `4pics1word/`, `4pics1wordTests/`, or `4pics1wordUITests/` is auto-included in the target. Do **not** hand-edit `project.pbxproj` to register new files.
- No `.xcworkspace`, no SPM resolution step, no `pod install` — just open the project.

### Clone & open
```bash
git clone https://github.com/dantech0xff/4pics1word.git
cd 4pics1word
open 4pics1word.xcodeproj   # or: xed .
```

### Pick a simulator
```bash
xcrun simctl list devices available
```

### Build (simulator)
```bash
xcodebuild -project 4pics1word.xcodeproj -scheme 4pics1word \
  -destination 'platform=iOS Simulator,name=iPhone 16' build
```

### Run all tests (unit + UI)
```bash
xcodebuild -project 4pics1word.xcodeproj -scheme 4pics1word \
  -destination 'platform=iOS Simulator,name=iPhone 16' test
```
> If parallel UI-test cloning flakes on a busy machine, add `-parallel-testing-enabled NO`.

### Run a single unit test (Swift Testing)
```bash
xcodebuild -project 4pics1word.xcodeproj -scheme 4pics1word \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  test -only-testing:4pics1wordTests/CheckInTests
```

### Code signing
- **Style:** Automatic (`CODE_SIGN_STYLE = Automatic`).
- **Team:** `CTSG43U4D8`.
- To run on a physical device, select your team in Xcode → Signing & Capabilities (the bundled team may not match yours).

### Adding puzzle content (no code change)
Drop four images named `<puzzleId>_1.webp` … `<puzzleId>_4.webp` into the app bundle. `LevelService.bundledImageIds()` auto-filters the level list to fully-imaged puzzles.

---

## Testing notes
- **Unit tests** (`4pics1wordTests/`) use **Swift Testing** (`import Testing`, `struct` + `@Test func`) — do **not** mix XCTest here.
- **UI tests** (`4pics1wordUITests/`) use `XCTestCase`.
- The app honors a `-uitest-reset` launch argument that wipes `progress.v1` + `settings.v1` before UI tests run (see `_pics1wordApp.init`).
- **Concurrency:** default actor isolation is `MainActor` (`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`). New code is `@MainActor`-isolated by default — mark `nonisolated` explicitly where needed.

---

## Features
- 4-pics-1-word gameplay loop with seamless level wrap-around (count hidden).
- Hint economy: Reveal (lock a correct letter), Remove (discard decoys), Shuffle (free).
- Daily check-in sheet — 7-day streak, Day-7 jackpot, live midnight countdown, coin-fly + jackpot confetti.
- Tap-to-zoom image viewer; photo credits screen.
- Light/Dark appearance toggle; haptics toggle; reset-progress.
- Accessibility: reduce-motion, reduce-transparency, Dynamic Type (capped `.accessibility2`) gates throughout.

---

## Documentation
Full docs live in [`docs/`](./docs):
- [Project overview & PDR](./docs/project-overview-pdr.md)
- [System architecture](./docs/system-architecture.md)
- [Codebase summary](./docs/codebase-summary.md)
- [Code standards](./docs/code-standards.md)
- [Design guidelines](./docs/design-guidelines.md)
- [Deployment guide](./docs/deployment-guide.md)
- [Project roadmap](./docs/project-roadmap.md)

## Status
Active development. No CI/CD, no Fastlane, no App Store submission pipeline yet — all builds/tests run locally via `xcodebuild`. See the [roadmap](./docs/project-roadmap.md).
