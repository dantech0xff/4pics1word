# Phase 04 — Tests & accessibility pass

## Context links
- Plan: [../plan.md](../plan.md)
- Research: [../research/researcher-01-report.md](../research/researcher-01-report.md) (§4 a11y, §5 haptics)
- Prev phase: [phase-03-enriched-daytile.md](./phase-03-enriched-daytile.md)

## Overview
- **Date:** 2026-06-28
- **Description:** Update UI test contract for gated Close (Phase 01 broke `testToolbarButtonReopensSheetAfterDismiss`), add a11y assertions, run full build+test.
- **Priority:** P2
- **Implementation status:** pending
- **Review status:** pending

## Key insights
- Phase 01 made pre-claim `Close` button `.disabled(true)`. XCTest `app.buttons["Close"].tap()` on a disabled button either no-ops or fails — must claim first.
- Swift Testing (unit target) unaffected — no unit tests touch this sheet's UI state.
- UI test target uses `XCTestCase` (per AGENTS.md) — keep style consistent.
- Per researcher-01 §4: assert Close remains in a11y tree when disabled (don't hide).

## Requirements
1. `testToolbarButtonReopensSheetAfterDismiss` (L58-71): claim → close → reopen.
2. (Optional, low-effort) new test: pre-claim Close is disabled / non-dismissing.
3. VoiceOver hint text verified (manual audit via Accessibility Inspector).
4. `xcodebuild build` green on iPhone 16 sim.
5. `xcodebuild test` green (all unit + UI tests).
6. No new test infrastructure (YAGNI).

## Architecture
Test-only phase. No app code changes. If Phase 01–03 missed anything, fix here.

```swift
// Updated testToolbarButtonReopensSheetAfterDismiss
func testToolbarButtonReopensSheetAfterDismiss() {
    let app = XCUIApplication()
    app.launchArguments += [Self.resetFlag]
    app.launch()

    let sheet = app.otherElements[Self.checkInView]
    XCTAssertTrue(sheet.waitForExistence(timeout: 25))

    // Phase 01 gate: Close is disabled pre-claim. Must claim first.
    app.buttons["Claim 20 coins"].tap()

    // Now Close is enabled.
    let close = app.buttons["Close"]
    XCTAssertTrue(close.waitForExistence(timeout: 5))
    close.tap()

    let toolbar = app.buttons["Daily check-in, reward available"]
    XCTAssertTrue(toolbar.waitForExistence(timeout: 5))
    toolbar.tap()
    XCTAssertTrue(sheet.waitForExistence(timeout: 5))
}
```

### Optional new test
```swift
func testCloseIsDisabledBeforeClaim() {
    let app = XCUIApplication()
    app.launchArguments += [Self.resetFlag]
    app.launch()

    let sheet = app.otherElements[Self.checkInView]
    XCTAssertTrue(sheet.waitForExistence(timeout: 25))

    let close = app.buttons["Close"]
    XCTAssertTrue(close.exists)
    XCTAssertFalse(close.isEnabled, "Close must be disabled while reward is claimable")

    // Tap is a no-op on disabled; sheet stays.
    if close.isEnabled { close.tap() }   // belt-and-suspenders
    XCTAssertTrue(sheet.exists, "Sheet should not dismiss pre-claim")
}
```

## Related code files
- `4pics1wordUITests/CheckInUITests.swift:58-71` — `testToolbarButtonReopensSheetAfterDismiss` (rewrite).
- `4pics1wordUITests/CheckInUITests.swift:22-34` — `testClaimShowsThenComeBackTomorrow` (verify still passes — claim flow unchanged).
- `4pics1wordUITests/CheckInUITests.swift:11-20` — `testCheckInSheetAutoAppearsOnFirstLaunch` (no change).
- `4pics1wordUITests/CheckInUITests.swift:36-56` — `testNoAutoSheetOnRelaunchAfterClaim` (no change).
- `4pics1word/Views/CheckInView.swift:71-77` — Close button (verify `.accessibilityIdentifier("Close")` label still resolves; the accessibility label "Close" is the query target).

## Implementation steps
1. Rewrite `testToolbarButtonReopensSheetAfterDismiss` per sketch above.
2. (Optional) Add `testCloseIsDisabledBeforeClaim`.
3. Run Accessibility Inspector on pre-claim sheet → confirm Close in tree, hint reads "Disabled until you claim today's reward…".
4. Run Accessibility Inspector on DayTile → confirm jackpot day announces "Jackpot".
5. `xcodebuild build` (iPhone 16 sim).
6. `xcodebuild test` (all targets).
7. Light/dark mode visual sweep.

## Todo
- [ ] Rewrite `testToolbarButtonReopensSheetAfterDismiss`
- [ ] Add `testCloseIsDisabledBeforeClaim` (optional)
- [ ] Accessibility Inspector audit (Close hint + DayTile jackpot)
- [ ] `xcodebuild -scheme 4pics1word build` green
- [ ] `xcodebuild -scheme 4pics1word test` green
- [ ] Light + dark mode visual sweep
- [ ] iPhone SE (375pt) + iPhone 16 Pro Max + iPad mini sweep

## Success criteria
- All 4 (or 5) UI tests pass.
- All unit tests pass (no Swift Testing regressions).
- Accessibility Inspector: no "Don't trap" violations; Close hint reads correctly; DayTile jackpot announced.
- Build green on iPhone 16 sim, no warnings introduced.

## Risk assessment
| Risk | Likelihood | Mitigation |
|---|---|---|
| Close query no longer resolves (label vs identifier) | Low | Use `.accessibilityLabel("Close")` consistently (current pattern L77) |
| `.disabled` Close tap crashes XCTest | Low | XCTest no-ops on disabled; verify in step 6 |
| New test flakes (timing) | Low | Use `waitForExistence(timeout:)` everywhere; reuse existing 25s pattern |
| iPad form-sheet breaks gate (open Q from researcher-01) | Med | Manual iPad sim sweep; file follow-up if broken |

## Security considerations
None. Test-only phase.

## Next steps
- Tag release / merge to main.
- File follow-up issues for out-of-scope items: countdown timer, mystery tile, streak flame, iPad form-sheet verification (if needed).

## Unresolved questions
1. Is the optional `testCloseIsDisabledBeforeClaim` worth the extra ~30s test time? → Recommend yes; small, high-signal, documents the gate contract.
2. Should we add a UI test for the 2-row layout (e.g., assert 2 HStack containers)? → Skip; layout is visual, not behavior. Manual sweep suffices.
