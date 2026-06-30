# Phase 04 — Tests, A11y, Build Verification

## Context links
- Parent plan: `../plan.md`
- Dependency: Phases 01 + 02 + 03 landed.
- Scout: `../scout/scout-01-report.md` (UI test target).
- Sources: `4pics1wordUITests/CheckInUITests.swift`, `4pics1word/Views/CheckInView.swift`.

## Overview
- Date: 2026-06-30
- Description: Fix 2 breaking UI tests asserting deleted "Come back tomorrow" copy; add assertions for countdown identifier + 3-3-1 grid; run full build/test green; a11y audit.
- Priority: P2
- Implementation status: pending
- Review status: pending

## Key Insights
- `testClaimShowsThenComeBackTomorrow` (L46–58) asserts `app.staticTexts["Come back tomorrow"]` (L55–56) — text deleted in Phase 03 → BREAKS.
- `testToolbarButtonReopensSheetAfterDismiss` (L99–100) asserts same text as gate before dismiss → BREAKS.
- Phase 03 adds `.accessibilityIdentifier("CheckInCountdown")` → query via `app.otherElements["CheckInCountdown"]` (or `descendants(matching:.any)` if SwiftUI surfaces it as staticText).
- Existing tests use label-based matching (L132–135, L144–148) — robust to layout change; jackpot label still reads "jackpot" (a11y label L484 unchanged).
- Module = `_pics1word`; UI tests = `XCTestCase` (do NOT use Swift Testing here). File-system synchronized groups → no `project.pbxproj` edit.

## Requirements
1. Update `testClaimShowsThenComeBackTomorrow` to assert `CheckInCountdown` exists (not deleted copy).
2. Update `testToolbarButtonReopensSheetAfterDismiss` gate assertion likewise.
3. Add test: 3-3-1 grid layout (jackpot tile full-width — query `Day7Jackpot` exists; visual width not assertable via XCTest, so assert presence + jackpot label only).
4. Add test: countdown appears post-claim (identifier exists).
5. (Optional) Add test: claimed tile a11y label still reads "claimed" (Phase 02 swap shouldn't change L487).
6. Full `xcodebuild build` + `test` green on iPhone 16 sim.
7. Manual a11y audit: VoiceOver reads countdown as spoken words; Dynamic Type at `.accessibility2` no truncation; reduce-motion countdown static.

## Architecture
No new test infra. Reuse `launchFresh()` (L14–19) + `waitForSheet(_:)` (L21–25) helpers.

### Test updates
```swift
func testClaimShowsCountdown() {                              // rename from ...ComeBackTomorrow
    let app = launchFresh()
    _ = waitForSheet(app)
    let claim = app.buttons["Claim 20 coins"]
    XCTAssertTrue(claim.waitForExistence(timeout: 25))
    claim.tap()
    let countdown = app.descendants(matching: .any)
        .matching(NSPredicate(format: "label CONTAINS %@", "Next reward")).firstMatch
    XCTAssertTrue(countdown.waitForExistence(timeout: 5),
                  "Claim did not transition to countdown state")
    XCTAssertFalse(claim.exists, "Claim button should disappear after claiming")
}
```
```swift
// In testToolbarButtonReopensSheetAfterDismiss (L99–100): replace
//   XCTAssertTrue(app.staticTexts["Come back tomorrow"].waitForExistence(timeout: 5), …)
// with:
let countdown = app.descendants(matching: .any)
    .matching(NSPredicate(format: "label CONTAINS %@", "Next reward")).firstMatch
XCTAssertTrue(countdown.waitForExistence(timeout: 5),
              "Claim did not transition to countdown state")
```
(Label-based match is more robust than identifier across SwiftUI element-type variance.)

### New tests
```swift
func testJackpotTileFullWidthRow() {
    let app = launchFresh()
    _ = waitForSheet(app)
    // Day-7 jackpot tile present (full-width row in 3-3-1 layout).
    let jackpot = app.descendants(matching: .any)
        .matching(NSPredicate(format: "label CONTAINS %@", "jackpot")).firstMatch
    XCTAssertTrue(jackpot.waitForExistence(timeout: 10), "Day-7 jackpot tile not found")
    XCTAssertTrue(jackpot.label.contains("100"))
}
```
```swift
func testCountdownIdentifierPostClaim() {
    let app = launchFresh()
    _ = waitForSheet(app)
    app.buttons["Claim 20 coins"].tap()
    let countdown = app.otherElements["CheckInCountdown"]
    XCTAssertTrue(countdown.waitForExistence(timeout: 5), "Countdown identifier not found post-claim")
}
```

## Related code files
- `4pics1wordUITests/CheckInUITests.swift` — L46–58 (rename/rewrite), L89–110 (update gate L99–100), append 2 new tests.
- `4pics1word/Views/CheckInView.swift` — read-only here (confirms identifiers: `CheckInCountdown` Phase 03, `Day7Jackpot` L300, `CheckInView` L63).

## Implementation Steps
1. Rename `testClaimShowsThenComeBackTomorrow` → `testClaimShowsCountdown`; rewrite body per Architecture.
2. L99–100: replace "Come back tomorrow" assertion w/ "Next reward" label assertion.
3. Append `testJackpotTileFullWidthRow`.
4. Append `testCountdownIdentifierPostClaim`.
5. (Opt) Append `testClaimedTileA11yReadsClaimed` — claim, assert a day-tile label CONTAINS "claimed".
6. Build: `xcodebuild -project 4pics1word.xcodeproj -scheme 4pics1word -destination 'platform=iOS Simulator,name=iPhone 16' build`.
7. Test: `xcodebuild -project 4pics1word.xcodeproj -scheme 4pics1word -destination 'platform=iOS Simulator,name=iPhone 16' test`.
8. Manual a11y: VoiceOver on → countdown spoken; Dynamic Type `.accessibility2` → no truncation; reduce-motion on → countdown static; reduce-motion off → per-digit slide.
9. iPad sim sanity: jackpot horizontal layout width reasonable (not absurd).

## Todo list
- [ ] Rename + rewrite `testClaimShowsCountdown`
- [ ] Update gate assertion in `testToolbarButtonReopensSheetAfterDismiss`
- [ ] Add `testJackpotTileFullWidthRow`
- [ ] Add `testCountdownIdentifierPostClaim`
- [ ] (Opt) Add `testClaimedTileA11yReadsClaimed`
- [ ] `xcodebuild build` green
- [ ] `xcodebuild test` green (all tests pass)
- [ ] Manual a11y audit (VoiceOver / AX2 / reduce-motion)
- [ ] iPad sim sanity check

## Success Criteria
- All UI tests pass on iPhone 16 sim (0 failures).
- No test references deleted "Come back tomorrow" copy.
- Countdown + jackpot presence asserted.
- Build + test green end-to-end.
- VoiceOver reads countdown spoken words; AX2 no truncation; reduce-motion countdown static.

## Risk Assessment
| Risk | Mitigation |
|---|---|
| `CheckInCountdown` identifier not exposed as `otherElement` (SwiftUI element-type variance) | Use `descendants(matching:.any).matching(label CONTAINS "Next reward")` fallback (matches existing L132–135 pattern). |
| Test flake: countdown TimelineView 1s tick delay | Assert on label presence (instant), not on a specific time value. |
| iPad jackpot row over-wide fails visual review | Sheet `.medium` bounds it; if still bad, defer `maxWidth` cap to follow-up (YAGNI now). |
| AX2 horizontal jackpot truncation | Phase 01 `shouldUseJackpotRow` excludes `isAccessibilitySize`. Verify here. |
| Test rename breaks CI name reference | No CI exists (AGENTS.md); safe. |
| Module-name gotcha (`_pics1word`) | UI test target imports app via launch only — no `@testable import` needed. N/A. |

## Security Considerations
None — test-only. No data/auth/network surface. No secrets in test fixtures.

## Next steps
→ Plan complete. All 3 product reqs delivered, tests green. Reply w/ file paths + summary; hand off to implementer (do NOT implement per task constraint).
