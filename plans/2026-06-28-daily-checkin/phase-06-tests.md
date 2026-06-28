# Phase 06 — Tests

## Context links
- Plan: [plan.md](plan.md)
- Research: [researcher-01 §2, §3, §5](../research/researcher-01-streak-mechanics.md)
- AGENTS.md: [Unit = Swift Testing, UI = XCTest](../../AGENTS.md)
- Prev: [phase-05-home-integration.md](phase-05-home-integration.md)

## Overview
- **Date:** 2026-06-28
- **Description:** Swift Testing unit tests for `CheckIn` + `AppModel.checkIn` (rollover, streak break, reward curve, double-claim, clock-rewind, reset). XCTest UI test for sheet presentation + claim flow.
- **Priority:** P2
- **Impl status:** done
- **Review status:** done

## Key Insights
- **Unit tests use Swift Testing** (`import Testing`, `struct` + `@Test func`) — NOT XCTest (AGENTS.md gotcha). UI tests use `XCTestCase`.
- **Inject `now:`** — every `CheckIn` function takes `now: Date = Date()` precisely so tests can pass fixed dates. No clock mocking needed.
- **Inject `ProgressStore(defaults:)`** — `ProgressStore` already accepts a custom `UserDefaults` (`ProgressStore.swift:7`). Tests use `UserDefaults(suiteName: UUID().uuidString)!` for isolation, then `.removeSuite`.
- **`@MainActor` default** — `AppModel` tests run on main actor automatically; no annotation.
- Reward curve wrap is the trickiest logic — cover days 1, 7, 8, 14, 15 explicitly.

## Requirements
1. New file `4pics1wordTests/CheckInTests.swift` — Swift Testing, covers `CheckIn` pure functions.
2. Extend existing `4pics1wordTests/_pics1wordTests.swift` (or new `AppModelCheckInTests.swift`) — covers `AppModel.checkIn()` + reset.
3. New file `4pics1wordUITests/CheckInUITests.swift` — XCTest, covers sheet presentation + claim.
4. All test dates constructed via `Calendar.current.date(byAdding:to:)` or fixed ISO strings parsed — never raw `Date()`.
5. Each test独立 `UserDefaults` suite (no shared state).

## Architecture
```
CheckInTests (struct, @Test funcs)
├─ rewardCurve: day 1→20, 7→100, 8→20, 14→100, 15→25
├─ dayDelta: nil/0/1/>1
├─ canClaim: never→true, sameDay→false, nextDay→true, gap→true
├─ rewindGuard: now < lastKnownNow-120s → false
└─ nextStreakDay: first→1, delta1→streak+1, delta>1→1

AppModelCheckInTests
├─ firstClaim: streak=1, coins+=20, lastCheckInDate set, lifetimeCheckIns=1
├─ doubleClaimSameDay: returns nil, no coin change
├─ claimNextDay: streak=2, coins+=25
├─ claimAfterGap: streak resets to 1
├─ day8Wrap: streak=8, reward=20 (wraps)
├─ resetProgress: clears all check-in fields, canCheckInToday=true
└─ rewindBlocks: lastKnownNow in future → checkIn returns nil

CheckInUITests (XCTest)
├─ firstLaunch_sheetAppears
├─ tapClaim_coinsIncrease
└─ relaunchSameDay_noAutoSheet
```

## Related code files
- `4pics1wordTests/CheckInTests.swift` — CREATE
- `4pics1wordTests/AppModelCheckInTests.swift` — CREATE
- `4pics1wordUITests/CheckInUITests.swift` — CREATE
- `4pics1word/Game/CheckIn.swift` — READ (subject under test)
- `4pics1word/Game/AppModel.swift` — READ (subject under test)
- `4pics1wordTests/_pics1wordTests.swift` — READ (existing style template)

## Implementation Steps
1. Create `4pics1wordTests/CheckInTests.swift`:
   ```swift
   import Testing
   import Foundation
   @testable import _pics1word

   struct CheckInTests {
       @Test func rewardCurveWrapsAt7() {
           #expect(CheckIn.reward(forStreakDay: 1) == 20)
           #expect(CheckIn.reward(forStreakDay: 7) == 100)
           #expect(CheckIn.reward(forStreakDay: 8) == 20)
           #expect(CheckIn.reward(forStreakDay: 14) == 100)
           #expect(CheckIn.reward(forStreakDay: 15) == 25)
       }

       @Test func dayDeltaNilWhenNeverClaimed() {
           #expect(CheckIn.dayDelta(from: nil, to: Date()) == nil)
       }

       @Test func dayDeltaSameDayIsZero() throws {
           let cal = Calendar.current
           let noon = cal.date(bySettingHour: 12, minute: 0, second: 0, of: Date())!
           let later = cal.date(bySettingHour: 23, minute: 59, second: 0, of: Date())!
           #expect(CheckIn.dayDelta(from: noon, to: later) == 0)
       }

       @Test func dayDeltaNextDayIsOne() {
           let cal = Calendar.current
           let today = cal.startOfDay(for: Date())
           let tomorrow = cal.date(byAdding: .day, value: 1, to: today)!
           #expect(CheckIn.dayDelta(from: today, to: tomorrow) == 1)
       }

       @Test func dayDeltaGapBreaksStreak() {
           let cal = Calendar.current
           let today = cal.startOfDay(for: Date())
           let threeDaysLater = cal.date(byAdding: .day, value: 3, to: today)!
           #expect(CheckIn.dayDelta(from: today, to: threeDaysLater) == 3)
       }

       @Test func canClaimFalseWhenRewindSuspected() {
           var p = Progress()
           p.lastKnownNow = Date().addingTimeInterval(3600)
           #expect(CheckIn.canClaim(p, now: Date()) == false)
       }

       @Test func nextStreakDayResetsOnGap() {
           var p = Progress()
           p.streakDays = 5
           p.lastCheckInDate = Calendar.current.date(byAdding: .day, value: -3, to: Date())
           #expect(CheckIn.nextStreakDay(p) == 1)
       }
   }
   ```
2. Create `4pics1wordTests/AppModelCheckInTests.swift` using isolated `UserDefaults`:
   ```swift
   @Test func firstClaimAwards20Coins() throws {
       let suite = "test-\(UUID().uuidString)"
       let defaults = UserDefaults(suiteName: suite)!
       let store = ProgressStore(defaults: defaults)
       let model = AppModel(store: store)
       let reward = model.checkIn()
       #expect(reward == 20)
       #expect(model.progress.coins == Progress.startingCoins + 20)
       #expect(model.progress.streakDays == 1)
       #expect(model.progress.lifetimeCheckIns == 1)
       defaults.removePersistentDomain(forName: suite)
   }
   ```
   Add: doubleClaimSameDay, claimNextDay, claimAfterGap, day8Wrap, resetClearsCheckin, rewindBlocksCheckin.
3. Create `4pics1wordUITests/CheckInUITests.swift` (XCTest):
   ```swift
   final class CheckInUITests: XCTestCase {
       func testFirstLaunchSheetAppears() throws {
           let app = XCUIApplication()
           app.launch()
           // splash 1.5s + 0.4s delay
           let sheet = app.otherElements["CheckInView"] // accessibilityIdentifier added in Phase 04
           XCTAssertTrue(sheet.waitForExistence(timeout: 3.0))
       }
       func testTapClaimIncreasesCoins() throws { ... }
   }
   ```
4. Add `accessibilityIdentifier("CheckInView")` to `CheckInView` root (Phase 04 amend).
5. Run: `xcodebuild -project 4pics1word.xcodeproj -scheme 4pics1word -destination 'platform=iOS Simulator,name=iPhone 16' test`.

## Todo list
- [ ] `CheckInTests.swift` (7+ @Test funcs)
- [ ] `AppModelCheckInTests.swift` (7+ @Test funcs, isolated UserDefaults)
- [ ] `CheckInUITests.swift` (3 tests)
- [ ] `accessibilityIdentifier("CheckInView")` added
- [ ] Full test suite green

## Success Criteria
- All unit tests pass deterministically (no `Date()` flakiness — all dates injected).
- Reward wrap (day 8/14/15) explicitly verified.
- Rewind guard blocks claim.
- `resetProgress()` clears check-in state.
- UI test confirms sheet auto-presents on first launch.
- Test suite runs < 30s on simulator.

## Risk Assessment
- **Risk:** Calendar-day tests flaky around midnight. **Mitigation:** tests use `startOfDay` + `byAdding: .day`, not raw offsets; tz-stable.
- **Risk:** UI test timing (splash 1.5s + popup 0.4s). **Mitigation:** `waitForExistence(timeout: 3.0)` generous; no hard sleep.
- **Risk:** Shared `UserDefaults.standard` pollutes other tests. **Mitigation:** every test uses unique suite + teardown.

## Security Considerations
Tests must verify the rewind guard works (security feature). Explicit `rewindBlocksCheckin` test: set `progress.lastKnownNow` to future, assert `checkIn() == nil` and coins unchanged. This is the only security-relevant assertion in the suite.

## Next steps
All phases complete. Hand off to implementer. After impl: manual QA on device (clock-change scenario, day-rollover overnight, iCloud restore).
