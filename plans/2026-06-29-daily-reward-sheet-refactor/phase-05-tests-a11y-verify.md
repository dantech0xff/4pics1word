# Phase 05 — Tests & Accessibility Verify

## Context links
- Plan: [../plan.md](../plan.md)
- Research: [../research/researcher-02-report.md](../research/researcher-02-report.md) (§9), [researcher-01-report.md](../research/researcher-01-report.md) (§5 iPad)
- Prev: [phase-04-claim-animation.md](./phase-04-claim-animation.md)
- Source: `4pics1wordUITests/CheckInUITests.swift` (full), `4pics1wordTests/CheckInTests.swift`, `4pics1wordTests/AppModelCheckInTests.swift`
- Repo conventions: `AGENTS.md` (Swift Testing unit, XCTest UI tests; module `_pics1word`; MainActor default)

## Overview
- **Date:** 2026-06-29
- **Description:** Update UI tests for non-expand sheet + new elements (dots, gift icon, fly); build+test green iPhone 16 sim; Dynamic Type / VoiceOver / reduce-motion / iPad audit.
- **Priority:** P2
- **Implementation status:** pending
- **Review status:** pending

## Key insights
- **Swift Testing (unit)** for pure logic (`CheckInTests`, `AppModelCheckInTests`) — `import Testing`, `struct`+`@Test`. Logic files unchanged this plan → existing unit tests should pass unchanged; re-run to confirm.
- **XCTestCase (UI)** for sheet flow (`CheckInUITests`). Update selectors if `accessibilityIdentifier`/labels changed (Phase 03 refined labels — verify no test relies on old label strings).
- **Non-expand assertion:** XCTest cannot directly query detents. Indirect: assert sheet frame height ≤ `.medium` threshold (via `app.otherElements["CheckInView"].frame.height`) — fragile; prefer manual sim verification + document. Or skip automated detent assertion (YAGNI; manual gate).
- **iPad audit:** researcher-01 §5 — `[.medium]` ignored on regular size class. Manual iPad sim run; document form-sheet + grabber behaviour. Not a test failure.
- **A11y audit (researcher-02 §9):** VoiceOver labels w/ "claim in N days"; reduce-motion kills fly/shimmer/confetti; reduce-transparency materials → solid; Dynamic Type `.accessibility2` cap.

## Requirements
### Functional
- F1: All existing UI tests (`CheckInUITests.swift`) pass, updated for Phase 02–04 element changes.
- F2: All existing unit tests pass unchanged (logic untouched).
- F3: New UI test asserts 7-dot progress row exists w/ `accessibilityIdentifier`.
- F4: New UI test asserts D7 jackpot cell renders `gift.fill` (via a11y label "jackpot" trait).
- F5: `xcodebuild build` + `test` green iPhone 16 sim.

### Non-functional
- NF1: Manual VoiceOver run — each cell reads full state ("claim in N days" for locked).
- NF2: Manual reduce-motion run — no fly, no shimmer, no confetti; counter crossfades.
- NF3: Manual reduce-transparency run — materials → solid; no invisible chips.
- NF4: Manual Dynamic Type `.accessibility2` — no overflow 4-up row.
- NF5: Manual iPad sim — form-sheet acknowledged (document, not "fix").
- NF6: Sim Daltonism — claimed vs locked distinguishable.

## Architecture
No new test infrastructure. Extend `CheckInUITests` w/ 2 new tests; add `accessibilityIdentifier`s to new elements (dots row, jackpot cell) in CheckInView.swift.

```swift
// CheckInUITests.swift — new tests
func testProgressDotsRowExists() {
    // launch fresh → assert app.otherElements["CheckInProgressDots"].exists
}
func testJackpotDayUsesGiftIcon() {
    // launch fresh → assert jackpot cell a11y label contains "jackpot" (Phase 03 label)
}

// CheckInView.swift — add identifiers
progressDots.accessibilityIdentifier("CheckInProgressDots")
// jackpot DayTile: .accessibilityIdentifier("Day7Jackpot") when isJackpot
```

Unit tests (Swift Testing) — verify still green:
```bash
xcodebuild ... test -only-testing:4pics1wordTests/CheckInTests
xcodebuild ... test -only-testing:4pics1wordTests/AppModelCheckInTests
```

## Related code files
- **Modify:** `4pics1wordUITests/CheckInUITests.swift` — add 2 tests (dots, jackpot); update any label-dependent assertions (Phase 03 changed a11y labels — grep for old strings).
- **Modify:** `4pics1word/Views/CheckInView.swift` — add `accessibilityIdentifier("CheckInProgressDots")` to dots row; `accessibilityIdentifier("Day7Jackpot")` to jackpot tile.
- **No change:** `4pics1wordTests/CheckInTests.swift`, `4pics1wordTests/AppModelCheckInTests.swift` (logic untouched — re-run only).
- **No change:** `CheckIn.swift`, `AppModel.swift`, `Feedback.swift`, `project.pbxproj`.

## Implementation steps
1. **Add identifiers** in CheckInView.swift: `progressDots` → `"CheckInProgressDots"`; jackpot DayTile → `"Day7Jackpot"`.
2. **Audit existing UI tests** (`CheckInUITests.swift`) — grep for old a11y label strings changed in Phase 03 ("Day N of 7" etc.); update assertions to match new labels (claimed/today/locked + "claim in N days").
3. **Add `testProgressDotsRowExists`** — fresh launch, assert `app.otherElements["CheckInProgressDots"].exists`.
4. **Add `testJackpotDayUsesGiftIcon`** — fresh launch, assert jackpot cell labelled "jackpot" exists; (icon itself not assertable via XCTest — assert via a11y label contains "jackpot").
5. **Run unit tests:** `CheckInTests`, `AppModelCheckInTests` — confirm green (no logic change).
6. **Build + full test:** `xcodebuild -project 4pics1word.xcodeproj -scheme 4pics1word -destination 'platform=iOS Simulator,name=iPhone 16' test`.
7. **Manual a11y audit (VoiceOver):** enable VoiceOver sim; navigate 7 cells; verify each reads correct state + "claim in N days" for locked.
8. **Manual reduce-motion:** Settings > Accessibility > Reduce Motion ON; claim → verify no fly/shimmer/confetti, counter crossfades.
9. **Manual reduce-transparency:** Settings > Accessibility > Reduce Transparency ON; verify lock chip solid (not invisible), backgrounds opaque.
10. **Manual Dynamic Type:** Settings > Accessibility > Larger Text → `.accessibility2`; verify 4-up row no overflow.
11. **Manual iPad sim:** run on iPad; document form-sheet + grabber (expected per researcher-01 §5); confirm no crash/regression.
12. **Sim Daltonism:** run; verify claimed (✓) vs locked (🔒) distinguishable without colour.
13. **Update reports/:** write `phase-05-verify-report.md` summarising all manual audit results.

## Todo
- [ ] Add `accessibilityIdentifier`s (dots row, jackpot tile)
- [ ] Audit + update existing UI test label assertions
- [ ] Add `testProgressDotsRowExists`
- [ ] Add `testJackpotDayUsesGiftIcon`
- [ ] Unit tests green (CheckInTests, AppModelCheckInTests)
- [ ] Full `xcodebuild test` green iPhone 16 sim
- [ ] Manual: VoiceOver label sweep (7 cells + "claim in N days")
- [ ] Manual: reduce-motion (no fly/shimmer/confetti)
- [ ] Manual: reduce-transparency (solid fallbacks)
- [ ] Manual: Dynamic Type `.accessibility2` (no overflow)
- [ ] Manual: iPad sim (form-sheet documented)
- [ ] Manual: Sim Daltonism (icon-based distinction)
- [ ] Write `reports/phase-05-verify-report.md`

## Success criteria
- `xcodebuild build` + `test` green iPhone 16 sim.
- All pre-existing UI tests pass (updated for label changes).
- 2 new UI tests pass (dots row, jackpot cell).
- Unit tests pass unchanged (logic untouched — proves scope discipline).
- VoiceOver reads every cell correctly incl "claim in N days".
- Reduce-motion: zero animation (fly/shimmer/confetti), counter crossfades.
- Reduce-transparency: materials swap to solid, nothing invisible.
- Dynamic Type `.accessibility2`: no layout overflow.
- iPad: form-sheet behaviour documented, no regression.
- Sim Daltonism: claimed/locked distinguishable.

## Risk assessment
| Risk | Likelihood | Mitigation |
|---|---|---|
| Phase 03 label change breaks existing UI test (string match) | High | Step 2 audits all label assertions; update before run |
| XCTest cannot assert detent non-expand | Med | Skip automated detent assertion; manual sim gate (Phase 01 verified). Document. |
| iPad form-sheet flunks a test expecting bottom-sheet | Low | No such test; manual-only audit |
| `accessibilityIdentifier` on jackpot tile collides w/ container `CheckInView` id | Low | Distinct strings; XCTest resolves by hierarchy |
| Fly animation flaky in UI test (timing) | Low | UI tests assert post-claim state, not mid-animation; reduce-motion test covers static path |

## Security considerations
None. Tests + manual audit only.

## Next steps
- Plan complete. All 5 phases shipped.
- Update `plan.md` frontmatter `status: completed`, `completed: <date>`.
- Optional follow-up (out of scope): cross-view coin fly to Home HUD; confetti jackpot-only; localisation width audit.

## Unresolved questions
1. **Detent automation** — any value in an automated non-expand assertion (frame height check)? Default skip (fragile; manual gate sufficient). Confirm.
2. **iPad hardening** — if iPad form-sheet grabber deemed unacceptable, escalate to custom overlay modal (new plan). Default accept.
3. **VoiceOver "claim in N days"** — confirm "N days" arithmetic correct across week-rollover (streak reset → day 1). Verify w/ `CheckIn.nextStreakDay` in unit test if logic exposed.
4. **Confetti scope final** — keep every-claim (current) vs jackpot-only? Decide before close.
5. **Localisation** — ship English-only (default) or audit DE/FR/JP pill widths? Default English-only; flag for i18n plan.
