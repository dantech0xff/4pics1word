# Scout 01 — Files for Daily Reward Sheet Revamp

## Target files (edit)
| File | Lines | Role |
|---|---|---|
| `4pics1word/Views/CheckInView.swift` | 574 | Main view: `CheckInView`, `DayTile`, `DayTileState`, overlays, `actionSection`, fly-coin, confetti |

### Key regions in CheckInView.swift
- **L48–73** `body` — root VStack (header / dayStrip / Spacer / actionSection).
- **L99–112** `dayStrip` — current grid: `HStack(0..<4)` + `HStack(4..<7)` (4+3). **Rewrite to 3+3+jackpot.**
- **L114–134** `progressDots` / `progressDot` — 7-dot row above grid (unchanged).
- **L136–148** `dayTile(for:)` — builds `DayTile`; passes `isJackpot: i == 6`, `todayDay`, `onClaim`.
- **L150–154** `tileState(for:)` — claimed/today/locked logic.
- **L156–182** `actionSection` — Claim button branch (true) vs `Text("Come back tomorrow")` + `Text("Next reward: N coins")` branch (false). **Rewrite false-branch to countdown.**
- **L260–497** `DayTile` struct — `contentColumn` L305–321 (DAY / coin `Image` L312 / reward `Text` L315), `stateOverlay` L356–385 (checkmark overlay L367–372), `jackpotBadge` L398–412, `todayPill`, `shimmerOverlay`, `todayCellFrameReader` L469–479, a11y labels L483–496.
- **L272–273** `@ScaledMetric cellHeight: CGFloat = 96`, `corner: CGFloat = 18`.
- **L499–573** `FlyingCoin`, `CoinFrames`, `CoinFramePreferenceKey`, `ConfettiOverlay` (unchanged infra).

## Reference files (read-only)
| File | Lines | Role |
|---|---|---|
| `4pics1word/Game/CheckIn.swift` | 31 | `rewards=[20,25,30,35,40,50,100]`, `dayDelta`, `canClaim`, `nextStreakDay`, `reward(forStreakDay:)` |
| `4pics1word/Views/AppRootView.swift` | ~50 | Sheet host: L24 `.sheet`, L27 `.interactiveDismissDisabled(model.canCheckInToday)`. Detent lives here (per prior plan). |
| `4pics1word/Game/AppModel.swift` | — | `canCheckInToday`, `progress` (`streakDays`, `lastCheckInDate`, `coins`), `checkIn()`. |
| `4pics1wordUITests/CheckInUITests.swift` | ~120 | UI tests; may need new assertions for countdown / 3-3-1 grid identifiers. |
| `4pics1wordTests/AppModelCheckInTests.swift`, `CheckInTests.swift` | — | Unit tests (likely unchanged — no logic change). |

## Module gotcha
Module = `_pics1word` (can't start w/ digit). Tests use `@testable import _pics1word`. New top-level types keep `_` prefix.

## Build/test
```
xcodebuild -project 4pics1word.xcodeproj -scheme 4pics1word \
  -destination 'platform=iOS Simulator,name=iPhone 16' build|test
```

## Unresolved
- Exact `.presentationDetents` currently set in AppRootView (need to read for sheet height budget on countdown copy width).
