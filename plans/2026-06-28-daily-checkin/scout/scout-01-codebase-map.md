# Scout Report — Codebase Map for Daily Check-in

## Module / Target
- Module: `_pics1word` (Swift id can't start with digit; files use `_` prefix at top level). Tests use `@testable import _pics1word`.
- Single target app, iOS 26.5, SwiftUI, `@MainActor` default isolation, Swift Testing (unit) + XCTest (UI).
- File-system synchronized groups: drop `.swift` files into source folders → auto-targeted. Never hand-edit `project.pbxproj`.

## Architecture (MVVM-ish via Observation)
- `AppModel` (`@Observable`): orchestrator. Owns `service: LevelService`, `store: ProgressStore`, `progress: Progress`, `settings: Settings`, `phase: AppPhase`, `gameState: PuzzleState?`. All mutations centralised here.
- `AppPhase`: `.home | .playing | .celebrating | .won`. Drives `fullScreenCover` + sheet.
- Persistence: `ProgressStore` (UserDefaults key `progress.v1`, JSON Codable). `Settings` stored separately (`settings.v1`).

## Existing Economy
- `Economy.swift`: `startingCoins = 100`, `reward(forTier:) = 25 + 5*tier`.
- `Progress` (Models.swift): `coins`, `currentLevelIndex`, `solvedIds: Set<Int>`.
- Coins granted on solve in `AppModel.handleSolved()`. No shop, no IAP.

## Navigation / UI Entry Points
- `AppRootView`: NavigationStack(HomeView) → fullScreenCover(GameView) → sheet(WinView). Routes: `.settings`, `.credits` via `navigationDestination`.
- `HomeView`: toolbar = `CoinCounter` (left) + gear (right); center title block; bottom Play/Continue button.
- `CoinCounter` (capsule chip with yellow circle + monospaced digit).

## Patterns to Match
- New types files use `_` prefix only at top-level module boundary; most internal types do NOT need it (existing types like `AppModel`, `Progress`, `Economy` have no prefix). Rule applies to file names of top-level app entry only (`_pics1wordApp.swift`). New files like `CheckIn.swift`, `CheckInView.swift` are fine.
- `@MainActor` default — no need to annotate.
- `@Observable` for state-holding types; pure value types (`Codable` struct) for persisted models.
- UserDefaults for persistence (no SwiftData / CoreData in use).
- Sheet/fullScreenCover presentation via `Binding<Bool>` derived from `AppModel` state.

## Integration Points for Daily Check-in
1. **Persistence**: extend `Progress` (or new struct + new UserDefaults key) with `lastCheckInDate`, `streakDays`, `lastCheckInReward`.
2. **Logic**: new `CheckIn` service/enum in `Game/` (mirrors `Economy.swift` style). Streak curve, day-rollover detection (Calendar.current.startOfDay).
3. **AppModel**: `checkIn()` method; track whether today already claimed; expose `canCheckInToday: Bool`.
4. **UI**: new `CheckInView` sheet, presented from `HomeView` (button next to CoinCounter or auto-prompt on launch). Bonus animation on claim.
5. **Reset**: `resetProgress()` should clear check-in state too.

## Unresolved
- Does "only receive coin via check-in" mean remove solve-rewards? → flag for user.
- Streak reward curve specifics → researcher to recommend.
- Auto-popup vs. manual button → researcher to recommend.
