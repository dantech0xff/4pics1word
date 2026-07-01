---
title: "AdMob Integration — Banner / Interstitial / Rewarded"
description: "First 3rd-party dep: GoogleMobileAds SDK via SPM. Dedicated @Observable AdsManager behind AdsManaging protocol injected into AppModel. Banner=HomeView-bottom only; interstitial=every 3rd level-complete ≥60s gap; rewarded=+50 coins. ATT after first solve. #if DEBUG test IDs + -uitest-reset kill-switch."
status: pending
priority: P1
effort: 14h
branch: master
tags: [ads, monetization, admob, sdk, att, privacy, ios]
created: 2026-07-02
---

# Plan — AdMob Integration

## Goal
Monetize the puzzle game with Google AdMob across 3 formats without breaking the zero-dep promise (now retired — see risks), the `@Observable AppModel` architecture, the 89 existing unit tests, or the offline-first UX. Brainstorm output: [`../../docs/brainstorm/2026-07-02-admob-integration.md`](../../docs/brainstorm/2026-07-02-admob-integration.md).

## Locked decisions (from brainstorm interview 2026-07-02)
| Area | Decision |
|---|---|
| Dependency | `GoogleMobileAds` SPM, **app target only**. No mediation adapters in v1. |
| **Ad IDs (2026-07-02 revision)** | **DEBUG-only / test IDs throughout.** No AdMob account yet → use Google's official sample App ID + test ad-unit IDs in BOTH Debug and Release configs. **Cannot ship to App Store in this state** (Apple rejects test ads; AdMob pays zero revenue). Submission deferred until real account + IDs registered. |
| Architecture | Dedicated `@Observable @MainActor AdsManager` behind `AdsManaging` protocol, injected into `AppModel`. `MockAdsManager` in unit-test target. |
| Banner | HomeView bottom only; hidden when `phase != .home`. Adaptive anchored banner via `UIViewControllerRepresentable`. |
| Interstitial | After `WinView` dismiss → `AppModel.nextLevel()`. Fire when `(completedSinceInterstitial % 3 == 0) && (now - lastInterstitialAt) ≥ 60s && adReady`. Silent skip if not ready. |
| Rewarded | +50 coins. Grant in SDK `userEarnedReward` callback (not dismiss). Exposed: HomeView "Free coins" button + hint-insufficient alert. |
| ATT | One-shot prompt after **first ever solve**. Pre-prompt explainer sheet. Until resolved: request non-personalized ads only. |
| UMP | EEA/UK consent via Google's `UMPRequestParameters` + built-in form. Never roll custom consent UI. |
| Dev/test | `#if DEBUG` ⇒ Google's official test ad-unit IDs. `AdsConfiguration.isAdsDisabled = CommandLine.arguments.contains("-uitest-reset")` → AdsManager is a no-op, banner renders a transparent spacer. CI = zero network. |

## Scope
**Create:**
- `4pics1word/Ads/AdsConfiguration.swift` — IDs (test/prod), kill-switch, UMP params.
- `4pics1word/Ads/AdsManaging.swift` — protocol + `RewardedGrant` typealias.
- `4pics1word/Ads/AdsManager.swift` — `@Observable @MainActor`. SDK init, UMP, preload, frequency/cooldown.
- `4pics1word/Ads/ATTRequester.swift` — `ATTrackingManager` wrapper, one-shot.
- `4pics1word/Ads/BannerHostView.swift` — `UIViewControllerRepresentable` wrapping `GADBannerView`.
- `4pics1word/Views/ATTExplainerView.swift` — pre-prompt sheet (one-shot).
- `4pics1wordTests/MockAdsManager.swift` — records call counts, exposes `fireGrant()` / `simulateInterstitialShown()`.

**Modify:**
- `4pics1word.xcodeproj/project.pbxproj` — add `GoogleMobileAds` SPM package + link to **app target only**. Add `Info.plist` keys (`GADApplicationIdentifier`, `NSUserTrackingUsageDescription`, `SKAdNetworkItems`). Add `PrivacyInfo.xcprivacy`.
- `4pics1word/Data/Models.swift` (`Progress`) — add `levelsCompletedSinceInterstitial: Int`, `lastInterstitialAt: Date?`, `hasSeenAttPrompt: Bool`. **Custom decoder must add `decodeIfPresent`** (existing explicit `CodingKeys` — see `Models.swift:46–62`).
- `4pics1word/Game/AppModel.swift` — `let ads: AdsManaging`; call `ads.maybeShowInterstitial()` in `nextLevel()` (L128); `grantRewardCoins(50)` on reward callback; trigger `ATTRequester` in `handleSolved` first-solve branch.
- `4pics1word/Views/HomeView.swift` — `BannerHostView` at bottom (L8 VStack); "Free coins" button when `progress.coins < HintCost.remove` (L90).
- `4pics1word/Views/AppRootView.swift` — `ads.start()` in `.task` (L32) after splash; ATT explainer sheet gate.
- `4pics1word/_pics1wordApp.init` — no change (`-uitest-reset` already wipes Settings; `AdsConfiguration.isAdsDisabled` reads same flag at runtime — see Phase 03).
- `4pics1word/Views/GameView.swift` — hint-insufficient alert: add "Watch ad for +50" action.

**Do NOT touch:** `PuzzleState.swift`, `CheckIn.swift`, `Economy.swift`, `Feedback.swift`, `ProgressStore.swift`, `LevelService.swift`, `PoolFactory.swift`, test target build settings (mock stays SDK-free).

## Architecture (cited)
- **Folder `4pics1word/Ads/`** — new top-level subsystem, mirrors existing `Game/`, `Data/`, `Views/`, `Components/` layout (see `docs/code-standards.md` File-organization table).
- **`@MainActor` default isolation** (`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`) — GAD delegates arrive on main by contract; no new annotations needed beyond confirming.
- **File-system synchronized groups ON** — new `.swift` files auto-register; **do NOT edit `project.pbxproj` to register source files**, only for SPM package + Info.plist (see `AGENTS.md` gotchas).
- **Module name `_pics1word`** — irrelevant inside app target (no `import _pics1word`); only matters in tests, which already use `@testable import _pics1word`.
- **Single mutation gate** — coin grants flow through `AppModel.grantRewardCoins()`, never directly from AdsManager into `Progress`. Matches the project's single-mutation-gate convention (`PuzzleState.canMutate`).
- **Backward-compat Progress decode** — `Models.swift:46` uses an explicit `CodingKeys` enum + `init(from:)` with `decodeIfPresent`. New fields must be added to both, else existing users' `progress.v1` JSON fails to decode.
- **Banner representable** — use `UIViewControllerRepresentable`, not raw `UIViewRepresentable`; safe-area/insets handling for adaptive banners needs a hosting VC (Google's own sample uses this). Project already bridges UIKit (`UIImage`, `Feedback` haptics).
- **Presenting VC for interstitial/rewarded** — GoogleMobileAds needs a `UIViewController`. Resolve via `UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.keyWindow?.rootViewController }.first` then walk to `presentedViewController` chain (helper in AdsManager).

## Phases
| # | Phase | Status | Effort | File |
|---|---|---|---|---|
| 01 | Project config: SPM, Info.plist, PrivacyInfo | pending | 2h | [phase-01-project-config.md](./phase-01-project-config.md) |
| 02 | Progress + Settings schema (backward-compat) | pending | 1h | [phase-02-progress-schema.md](./phase-02-progress-schema.md) |
| 03 | AdsConfiguration + AdsManaging protocol + Mock | pending | 1.5h | [phase-03-config-protocol-mock.md](./phase-03-config-protocol-mock.md) |
| 04 | ATTRequester + UMP + ATT explainer sheet | pending | 2h | [phase-04-att-ump.md](./phase-04-att-ump.md) |
| 05 | AdsManager implementation (init/preload/frequency) | pending | 3h | [phase-05-ads-manager.md](./phase-05-ads-manager.md) |
| 06 | Banner representable + HomeView wiring | pending | 1.5h | [phase-06-banner-homeview.md](./phase-06-banner-homeview.md) |
| 07 | Interstitial AppModel integration | pending | 1h | [phase-07-interstitial-appmodel.md](./phase-07-interstitial-appmodel.md) |
| 08 | Rewarded UI surfaces (HomeView + hint alert) | pending | 1.5h | [phase-08-rewarded-ui.md](./phase-08-rewarded-ui.md) |
| 09 | Tests + full build verification | pending | 2.5h | [phase-09-tests-build.md](./phase-09-tests-build.md) |

**Total: 16h.**

## Phase ordering
- **01 first** — no other phase compiles without the SDK linked.
- **02 second** — schema fields are read/written by Phases 05, 07.
- **03 parallel-safe w/ 02** — protocol + mock are leaf types.
- **04 after 02** — `hasSeenAttPrompt` lives in Progress.
- **05 after 01+03+04** — depends on SDK, protocol, ATT/UMP.
- **06, 07, 08 after 05** — all consume AdsManager. 06/07/08 are mutually parallel-safe (disjoint files except AppModel — 07 owns the AppModel edit; 08 reads `progress.coins`).
- **09 last** — final verification gate.

## Success criteria (plan-level)
- App builds + all 89 existing unit tests pass unchanged (with `MockAdsManager` injected).
- New unit tests pass: frequency cap (every 3rd), cooldown (≥60s), reward idempotency (grant fires once per callback), `-uitest-reset` kill-switch disables all surfaces.
- UI tests pass: banner present on HomeView; interstitial suppressed under `-uitest-reset`; no network calls in CI.
- Manual: first-solve → ATT pre-prompt → ATT prompt; subsequent solves no re-prompt.
- Manual: complete 3 puzzles → interstitial shown after 3rd WinView dismiss; next interstitial ≥60s later.
- Manual: tap HomeView "Free coins" → rewarded → +50 coins; kill app mid-ad → no grant.
- Release build (production IDs) on TestFlight: 3 formats fill rate >0 on a real device.

## Out of scope (YAGNI)
- Mediation adapters (Meta Audience Network, AppLovin, ironSource, Mintegral).
- Remote-config kill-switch / frequency dashboard.
- A/B testing ad placements or cadences.
- Custom in-house consent UI.
- Apple Search Ads / ATN integration.
- "Double daily reward via ad" upsell (flagged in brainstorm Q2 — roadmap).
- Banner on GameView (rejected in brainstorm).
- rewarded-for-free-hint (rejected in brainstorm — only coin grants).
- **Real AdMob account / production ad-unit IDs** — deferred until account is registered. Current plan uses test IDs throughout (see Locked decisions). When real IDs arrive, swap in `AdsConfiguration` + `Info.plist GADApplicationIdentifier` only — no architecture change.

## Risks (top 5 from brainstorm §"Brutal honesty")
1. **Reward double-grant on background** — Phase 05 + 07 + 09 enforce grant-in-callback + immediate persist + idempotency test.
2. **ATT/UMP not resolved = NPA-only banner** — Phase 04 sets `extras.extras = ["npa":"1"]` until ATT resolved; banner still fills at lower CPM.
3. **Interstitial not ready at level-3** — `AdsManager.maybeShowInterstitial` silent-skips when `interstitial == nil`.
4. **Test ads leak to production** — Phase 01 uses `#if DEBUG` gate; Phase 09 adds Release-build check.
5. **Kids category submission trap** — Phase 09 ships a submission checklist item: do NOT pick Kids category in App Store Connect.

## Resolved decisions (brainstorm interview 2026-07-02 — see brainstorm report)
All 6 brainstorm questions answered "Recommended." Locked. Open Q1 (reward-from-hint-alert) resolved: **yes**, include (Phase 08). Q2 (daily-double-ad) deferred to roadmap. Q3 (banner size): **adaptive anchored banner**.

## Open questions (empirical only)
1. **ATT prompt copy** — final wording TBD Phase 04 (must explain value clearly: "Keeps the game free").
2. **Google SKAdNetwork ID list currency** — at Phase 01 implementation, fetch the latest list from Google's docs (changes ~yearly).
3. **Interstitial frequency perception** — 3-level cadence feels right per industry norm; revisit after TestFlight beta if D1 retention drops.
4. **Reward button visibility threshold** — show when `coins < HintCost.remove` (90) is a guess; revisit after Phase 09 metrics.
