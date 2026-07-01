# Phase 09 — Tests + Full Build Verification

## Context links
- Parent plan: `../plan.md`
- Dependency: Phases 01–08 all complete.
- Brainstorm: §"Testability strategy" + §"Success metrics".
- Source: `4pics1wordTests/`, `4pics1wordUITests/`, `4pics1word.xcodeproj`.

## Overview
- Date: 2026-07-02
- Description: Add unit + UI tests covering the new ads surfaces; verify all 89 existing tests still pass; verify Release build green; document the App Store Connect submission checklist (Kids category trap).
- Priority: P1
- Implementation status: pending
- Review status: pending

## Key Insights
- **Unit tests stay SDK-free** — they inject `MockAdsManager`, never touch `GoogleMobileAds`. Test the AppModel math, not the SDK.
- **UI tests use `-uitest-reset`** — full kill-switch; verify banner absent + interstitial suppressed + no network calls.
- **`Progress` backward-compat test** — decode a known JSON blob missing new fields; assert defaults applied. Catches CodingKeys drift.
- **Real-device / TestFlight verification** — fill rate >0 requires a physical device on production build. Note as a post-merge gate, not a CI gate (no CI exists).
- **App Store Connect submission checklist** — do NOT pick Kids category; declare AdMob data collection (Identifiers, Product Interaction, Crash Data, Performance); add Privacy Policy URL.

## Requirements
1. New unit tests pass: interstitial frequency (every 3rd), cooldown (≥60s), reward grant idempotency, `-uitest-reset` kill-switch, ATT first-solve flag.
2. New unit test: `Progress` backward-compat decode.
3. New UI tests pass: banner present on HomeView (DEBUG, no `-uitest-reset`); banner absent under `-uitest-reset`; interstitial suppressed under `-uitest-reset`.
4. All 89 pre-existing tests pass unchanged.
5. Release build green (production IDs).
6. TestFlight-style submission checklist doc created.

## Architecture

### Unit tests (`4pics1wordTests/AdsTests.swift` — Swift Testing)
```swift
import Testing
import Foundation
@testable import _pics1word

@MainActor
struct AdsTests {
    @Test func interstitial_shows_every_third_within_cooldown() {
        let model = AppModel(ads: MockAdsManager(), service: .load(), store: .init())
        model.progress.lastInterstitialAt = Date()                       // within 60s
        model.progress.levelsCompletedSinceInterstitial = 2
        // simulate 3rd completion via nextLevel
        model.nextLevel()
        // expect: counter reset, lastInterstitialAt updated, mock called
        // (assert via injected mock instance — refactor tests to keep a ref)
    }

    @Test func interstitial_skipped_under_cooldown() { /* set lastInterstitialAt = now, counter = 3 → not shown */ }

    @Test func reward_grant_persists_synchronously() {
        let model = AppModel(ads: MockAdsManager())
        let before = model.progress.coins
        model.grantRewardCoins(Economy.rewardedAdPayout)
        #expect(model.progress.coins == before + 50)
    }

    @Test func att_flag_flips_on_first_solve_only() { /* solve twice → flag set once, explainer triggered once */ }

    @Test func progress_decodes_old_json_without_new_fields() {
        let old = """
        {"currentLevelIndex":0,"coins":100,"solvedIds":[],"streakDays":0,"lifetimeCheckIns":0}
        """.data(using: .utf8)!
        let p = try? JSONDecoder().decode(Progress.self, from: old)
        #expect(p?.levelsCompletedSinceInterstitial == 0)
        #expect(p?.lastInterstitialAt == nil)
        #expect(p?.hasSeenAttPrompt == false)
    }

    @Test func kill_switch_disables_ads() {
        // inject launch arg via a helper test setup; assert AdsConfiguration.isAdsDisabled == true
        // (requires test process to carry the flag — or split into a UI test)
    }
}
```
Note: keep a reference to the `MockAdsManager` instance so tests can assert `interstitialCallCount`. Refactor `AppModel.init` accordingly or expose `model.ads as? MockAdsManager`.

### UI tests (`4pics1wordUITests/AdsUITests.swift` — XCTest)
```swift
import XCTest

final class AdsUITests: XCTestCase {
    func test_banner_present_on_home_in_debug() throws {
        let app = XCUIApplication()
        // NO -uitest-reset → banner visible in DEBUG
        app.launch()
        // wait for splash, then assert banner exists (accessibility identifier on BannerHostView host.view)
    }

    func test_banner_absent_under_uitest_reset() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uitest-reset"]
        app.launch()
        // assert banner NOT present
    }
}
```

## Implementation Steps
1. Write `4pics1wordTests/AdsTests.swift`.
2. Write `4pics1wordUITests/AdsUITests.swift`.
3. Add accessibility identifier on `BannerHostView` host.view (`"adBanner"`).
4. Run full test suite (unit + UI).
5. Confirm 89 + new all green.
6. Build Release configuration: `xcodebuild -project 4pics1word.xcodeproj -scheme 4pics1word -configuration Release -destination 'platform=iOS Simulator,name=iPhone 16' build`.
7. ⚠️ **Skip the "grep Release binary for test IDs" check** — test IDs are intentional in BOTH configs (no AdMob account yet). Instead: confirm `AdsConfiguration.appId == "ca-app-pub-3940256099942544~1458002511"` (regression guard for the future prod-ID swap).
8. Write `docs/brainstorm/2026-07-02-admob-integration.md` appendix: submission checklist, **with a prominent SUBMIT-BLOCKED note** — app cannot ship until real AdMob account + IDs replace the test IDs in `Info.plist` + `AdsConfiguration`.
9. Update `README.md` — retire "no SPM packages" claim.
10. Update `docs/system-architecture.md` — add Ads subsystem section.
11. Update `docs/codebase-summary.md` — add Ads folder entries.
12. Update `docs/project-roadmap.md` — add Shipped entry + "submit-blocked on AdMob account" caveat.
13. Commit: `test(ads): unit + UI coverage; release verification; docs sync [phase-09]`.

## todo list
- [ ] `AdsTests.swift` — frequency, cooldown, reward idempotency, ATT, backward-compat
- [ ] `AdsUITests.swift` — banner present/absent
- [ ] Accessibility ID on banner host
- [ ] Mock instance assertion refactor
- [ ] Full suite green (89 + new)
- [ ] Release build green
- [ ] Confirm `AdsConfiguration.appId` == sample App ID (regression guard)
- [ ] Brainstorm report appendix: submission checklist + SUBMIT-BLOCKED note
- [ ] README.md — retire "no SPM" claim
- [ ] system-architecture.md — add Ads subsystem
- [ ] codebase-summary.md — add Ads folder
- [ ] project-roadmap.md — Shipped entry + submit-blocked caveat
- [ ] Commit

## Success Criteria
- All unit + UI tests green.
- Release binary builds (test IDs intentional — no grep check).
- `AdsConfiguration.appId` regression test guards the future swap to real IDs.
- Docs reflect new subsystem + retired zero-dep claim + submit-blocked caveat.
- Submission checklist present, marked **blocked on AdMob account registration**.

## Risk Assessment
| Risk | Mitigation |
|---|---|
| MockAdsManager not reachable via AppModel for assertion | Expose via cast or inject a known mock ref in test setup. |
| Real-device / TestFlight fill rate unverifiable in CI | Document as post-merge manual gate; no CI today. |
| UI test banner detection unreliable (adaptive banner frame varies) | Use accessibility identifier, not frame. |
| **Accidental submission with test IDs** (Apple reject + $0 revenue) | Phase 09 submission checklist explicitly marks app submit-blocked; roadmap notes the blocker; commit messages reference "test IDs". |
| Privacy questionnaire incomplete → rejection | Moot while submit-blocked; checklist covers required fields for when unblocked. |
| Kids category trap | Checklist explicitly warns (moot until unblocked). |

## Security Considerations
- Real ad-unit IDs are public; no secret leakage concern.
- Privacy Policy URL must be live before submission (stakeholder task).

## Next steps
→ Plan complete. Hand off to implementation. Suggest: `/set-active-plan plans/2026-07-02-admob-integration` if your runtime supports it, or proceed phase-by-phase with code-reviewer subagent between phases.

## Open questions (resolved empirically during this phase)
1. Default `ads` in AppModel.init vs explicit injection in tests — confirm chosen strategy in commit msg.
2. Real ad-unit ID values inserted in `AdsConfiguration` Release branch (Phase 01 capture).
3. ATT explainer copy final wording — Phase 04 deferred to here for review.
