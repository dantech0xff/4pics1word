# Brainstorm — AdMob Integration (Banner / Interstitial / Rewarded)

Date: 2026-07-02 · Status: agreed · Output for `/plan` follow-up.

## Problem statement
Integrate Google AdMob (banner, interstitial, rewarded video) into a **currently zero-dependency, offline-first** SwiftUI puzzle game. Add monetization without breaking the `@Observable AppModel` architecture, the 89 unit tests, or the stated "no third-party SPM" principle.

## Decisions (locked, via interview)
| Area | Choice |
|---|---|
| Dependency scope | **AdMob only** (`GoogleMobileAds` via SPM). Mediation deferred — adapters slot into the same `GADRequest` later. |
| ATT prompt timing | **After first solve.** Pre-prompt explainer view, one-shot flag in `Progress`. |
| Rewarded reward | **+50 coins** (≈ 1 Remove hint or ~2 Reveals; aligned with daily check-in tier). |
| Interstitial cadence | **Every 3rd level-complete, ≥60s gap.** Triggered after `WinView` dismiss → `nextLevel()`. Never mid-puzzle. |
| Banner placement | **HomeView bottom only.** Hidden during `playing`/`celebrating`/`won`. |
| Dev/test config | **`#if DEBUG` test ad-unit IDs** + full `AdsManager` disable when `-uitest-reset` present. |

## Brutal honesty — what the docs won't tell you
1. **This is the first 3rd-party dep.** `GoogleMobileAds` SPM binary ≈ 30–40 MB; expect build-time increase + first-clean-rebuild cost. The README claim "no SPM packages" must be retired.
2. **ATT after first solve = best opt-in BUT adds wiring.** You need a one-time `hasSeenAttPrompt` flag in `Progress`, a pre-prompt explainer View, and the prompt itself (`ATTrackingManager.requestTrackingAuthorization`). Until resolved, request **only non-personalized** ads via `GADRequestConfiguration`.
3. **UMP consent is NOT optional for EEA/UK.** Even with the "Skip ATT" path rejected, EEA users still need UMP. Use `UMPRequestParameters` + Google's built-in form — do **not** roll your own consent UI.
4. **`PrivacyInfo.xcprivacy` is now mandatory** (Apple Spring 2024). Google ships a reference manifest for the SDK; you must add your own for any custom tracking (none here, so adopt Google's).
5. **`SKAdNetworkItems` + `GADApplicationIdentifier` go in Info.plist.** Missing either = silent no-fill. Google publishes the current SKAdNetwork ID list; update annually.
6. **Reward video has a well-known exploit.** Grant coins in `rewardedAd(_:userEarnedReward:)` callback, **never** on ad dismiss — otherwise killing the app mid-ad = free reward. Persist immediately (reuse `store.save(progress)`).
7. **Interstitial/rewarded must preload.** Load latency 1–2s; if you wait until the user-triggered moment you get a spinner and abandoned impressions. Warm both in `AppModel.startLevel` and on app launch.
8. **"Kids" App Store category forbids ads.** When you submit, do **not** pick Kids as primary/secondary category — AdMob is incompatible. Casual/Puzzle/Word is fine.
9. **No CI today.** Ad SDK network calls in CI will hang UI tests. The `-uitest-reset` disable hook (already in `_pics1wordApp.init`) is the right seam — extend it.
10. **Banner in SwiftUI via `UIViewRepresentable` is fragile** for safe-area/keyboard insets. Prefer `UIViewControllerRepresentable` wrapping a tiny VC that hosts `GADBannerView`, or use Google's official SwiftUI sample pattern. The project already bridges UIKit for `UIImage` + `Feedback` haptics, so this fits.
11. **`@MainActor` default isolation.** All GAD delegate callbacks arrive on main thread by contract; keep `AdsManager` `@MainActor`-isolated (matches project default). Don't sprinkle `nonisolated`.

## Evaluated approaches

### A. Direct SDK calls inside AppModel (REJECTED)
Drop `GADInterstitial`, `GADRewardedAd`, `GADBannerView` directly into `AppModel` and Views.
- ✅ Fewest files.
- ❌ Couples domain model to SDK → untestable, 89 unit tests break.
- ❌ Violates single-mutation-gate convention.
- **Verdict:** violates DRY + testability. Hard no.

### B. Dedicated `AdsManager` @Observable, injected into AppModel (RECOMMENDED)
New `4pics1word/Ads/AdsManager.swift` (`@Observable final class`, `@MainActor`). `AppModel` holds `ads: AdsManaging` (protocol). Production wires real `AdsManager`; unit tests inject a `MockAdsManager` recording calls + instantly firing reward/interstitial callbacks.
- ✅ Test seam preserved — `AppModel` tests stay SDK-free.
- ✅ One place for preload / frequency / cooldown logic (DRY).
- ✅ Future mediation swaps behind the same protocol.
- ✅ Banner View holds `AdsManager` reference; interstitial/rewarded go through `AppModel` calls so coin grants land in one mutation gate.
- ❌ One extra file + a protocol (small price for an SDK boundary).
- **Verdict:** matches existing architecture (`LevelService`, `ProgressStore` are similarly injected). Pick this.

### C. Apple Search Ads + AdMob SDK (REJECTED for v1)
Wire both networks up front.
- ❌ YAGNI. ASA needs its own ATN integration + paid search spend. Not monetization, it's user acquisition.
- **Verdict:** defer indefinitely.

## Recommended architecture

```
4pics1word/
├── Ads/                                  ← NEW folder
│   ├── AdsManager.swift                  ← @Observable @MainActor, owns GAD* instances, preloads, frequency/cooldown
│   ├── AdsConfiguration.swift            ← ad-unit IDs (test vs prod via #if DEBUG), kill-switch flag
│   ├── AdsViewControllerRepresentable.swift  ← UIViewControllerRepresentable hosting GADBannerView
│   └── ATTRequester.swift                ← ATTrackingManager wrapper, one-shot
├── Game/
│   ├── AppModel.swift                    ← +ads: AdsManaging, calls into ads on nextLevel/grantReward
│   ├── Settings.swift                    ← +hasSeenAttPrompt flag persisted (or in Progress)
│   └── Progress.swift (Data/Models)      ← +interstitialsShownCount, +lastInterstitialAt
└── Views/
    └── HomeView.swift                    ← BannerView(ads: model.ads) at bottom; ConditionalDisplay
```

### Key flows
- **Startup** (`AppRootView.task` after splash): `ads.start()` → SDK init → UMP request → preload interstitial + rewarded → banner auto-fills.
- **First solve**: `handleSolved` bumps counter → after first ever solve, `ATTRequester.requestIfNeeded()` with pre-prompt explainer sheet.
- **Every `nextLevel()`**: `ads.maybeShowInterstitial(from: scene)` — `AdsManager` checks `(interstitialsShownCount % 3 == 0) && (now - lastInterstitialAt) ≥ 60s && adLoaded`. Presenting VC = top `UIWindow` rootVC (GoogleMobileAds requires a presenting VC; SwiftUI-bridge helper needed).
- **Reward**: HomeView "Free coins" button (visible when `progress.coins < 90`) + button on hint-insufficient alert → `ads.showRewarded { grant in model.grantRewardCoins(50) }`. Grant fires inside SDK reward callback, persists synchronously.
- **Banner**: `HomeView` bottom safe-area; hidden by `if model.phase == .home`.

### Info.plist additions (must-not-forget)
- `GADApplicationIdentifier` (real, from AdMob console)
- `NSUserTrackingUsageDescription` (required for ATT)
- `SKAdNetworkItems` array (Google's published IDs)
- `LSApplicationQueriesSchemes`: none new (AdMob handles its own)
- Add `PrivacyInfo.xcprivacy` (Google's reference manifest)

### Build settings
- Add `GoogleMobileAds` SPM package (v11+) to **app target only** — never to test targets.
- No `project.pbxproj` hand-edit for new `.swift` files (file-synchronized groups).

## Testability strategy
- `protocol AdsManaging { func start(); func preloadRewarded(); func showRewarded(onGrant: @escaping ()->Void); func maybeShowInterstitial(); var bannerReady: Bool { get } }`
- `MockAdsManager` in unit-test target: records call counts, exposes `fireGrant()` to simulate reward callback synchronously.
- `AdsConfiguration.isAdsDisabled = CommandLine.arguments.contains("-uitest-reset")` → `AdsManager` becomes a no-op (banner renders a transparent spacer).
- UI tests get no network calls — keeps CI flake-free.

## Risks & mitigations
| Risk | Mitigation |
|---|---|
| Reward double-grant if user backgrounds mid-ad | Grant only in `userEarnedReward` callback + immediate `store.save`. |
| ATT prompt suppresses ad load → revenue stall first session | Pre-prompt explainer clarifies value; default to NPA request until ATT resolved so banner still fills. |
| Interstitial not ready at level-3 boundary | Silent skip (`ad == nil` → no-op). Never block UX. |
| Test ads shown in production | `#if DEBUG` ⇒ test IDs; Release config carries real IDs. CI also enforced via `-uitest-reset`. |
| Kids category submission trap | Submission checklist item: do NOT pick Kids category. |
| Privacy questionnaire mismatch | AdMob SDK data collection must be declared in App Store Connect (Identifier for Advertisers, product interaction, crash data, performance). |

## Success metrics / validation
- All 89 existing unit tests still pass with `MockAdsManager` injected.
- New unit tests: frequency capping math, reward grant idempotency, cooldown enforcement, `-uitest-reset` kill-switch.
- New UI test: banner presence on HomeView; rewarded flow grants coins; interstitial suppressed under `-uitest-reset`.
- First run on TestFlight with production IDs: verify fill rate >0 for all 3 formats on a real device, ATT prompt appears once after first solve.

## Out of scope (YAGNI-deferred)
- Mediation adapters (Meta/AppLovin/ironSource) — slot via same `GADRequest` later.
- Frequency-capping dashboard / remote config.
- A/B testing ad placements.
- Custom in-house consent UI (use UMP).
- Apple Search Ads integration.

## Next steps
1. Acceptance gate: confirm the **HomeView-only banner** constraint with stakeholder (slight revenue ceiling vs zero gameplay UX risk — recommend keeping).
2. Create AdMob account, register app + 3 ad units, capture real IDs for Release config.
3. Run `/plan 2026-07-02-admob-integration` (this doc as context) to generate phase-by-phase implementation plan.

## Unresolved questions
- Q1: Should rewarded video also unlock from the **hint-insufficient alert** (e.g., "Not enough coins — watch ad for +50?"), or only from a dedicated HomeView button? Recommended: both, but confirm.
- Q2: Should the daily check-in sheet offer a "double reward via ad" upsell (common pattern)? Not in v1 — deferred; flag for roadmap.
- Q3: Preferred banner size — adaptive anchored banner (Google recommended) vs legacy 320×50? Recommend adaptive.
