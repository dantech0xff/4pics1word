# Phase 05 — AdsManager Implementation (init / preload / frequency)

## Context links
- Parent plan: `../plan.md`
- Dependency: Phase 01 (SDK), Phase 03 (protocol + config), Phase 04 (ATT/UMP).
- Brainstorm: §"Recommended architecture" + §"Brutal honesty" items 6, 7.
- Source: new `4pics1word/Ads/AdsManager.swift`; reads Phase 02 `Progress` fields (injected by AppModel in Phase 07).

## Overview
- Date: 2026-07-02
- Description: Concrete `AdsManager` conforming to `AdsManaging`. SDK init, UMP consent flow, preloaded interstitial + rewarded instances, NPA extra wiring, top-VC helper, reward-grant callback (grant-in-callback, never on dismiss).
- Priority: P1
- Implementation status: pending
- Review status: pending

## Key Insights
- **`@Observable @MainActor final class`** — matches `AppModel`/`PuzzleState` pattern (`docs/code-standards.md` State management). All GAD delegate callbacks arrive on main by contract.
- **Preload lazily, refresh on dismiss.** Load interstitial + rewarded at `start()`; on each `adDidDismiss`, immediately load the next. Avoids "Loading…" spinners at show-time.
- **Reward grant MUST happen in `rewardedAd(_:userEarnedReward:)`** — not in `adDidDismissFullScreenContent`. Kill-app-mid-ad exploit otherwise. Phase 07 wires the grant closure through AppModel.
- **NPA extra** — `GADRequest().setValue("1", forKey: "npa")` via `GADExtras` while `ATTRequester.shouldUseNonPersonalizedAds()` is true.
- **Top-VC helper** — GoogleMobileAds needs a presenting `UIViewController`. Resolve from key window root + walk `presentedViewController` chain.
- **`bannerReady` observable** — banner instance is owned by `BannerHostView` (Phase 06), but `bannerReady` lets HomeView gate visibility. Simpler: banner just auto-fills via its delegate; expose `bannerReady` for tests.
- **Kill-switch short-circuit** — every public method early-returns when `AdsConfiguration.isAdsDisabled`.

## Requirements
1. `AdsManager` conforms to `AdsManaging`, is `@Observable @MainActor final class`.
2. `start()` → SDK init (`GADMobileAds.sharedInstance().start()`), UMP request, preload interstitial + rewarded.
3. `preloadRewarded()` load-on-demand + on-dismiss-reload.
4. `showRewarded(onGrant:)` — present only if loaded; invoke `onGrant` exactly once when SDK fires `userEarnedReward`; persist progress in `onGrant` (Phase 07 closure).
5. `maybeShowInterstitial()` — checked at call site (Phase 07 AppModel pre-checks frequency/cooldown via Progress fields); actual show only if `interstitial != nil`.
6. `bannerReady: Bool` observable; flipped by `GADBannerViewDelegate`.
7. All public methods no-op when `AdsConfiguration.isAdsDisabled`.
8. All 89 tests pass (mock still injected into AppModel in Phase 07).

## Architecture

### `4pics1word/Ads/AdsManager.swift` (skeleton)
```swift
import GoogleMobileAds
import Observation
import UIKit

@MainActor
@Observable
final class AdsManager: NSObject, AdsManaging, GADFullScreenContentDelegate, GADBannerViewDelegate {
    private(set) var bannerReady = false
    private var interstitial: GADInterstitialAd?
    private var rewarded: GADRewardedAd?
    private var pendingGrant: RewardGrant?

    override init() { super.init() }

    func start() {
        guard !AdsConfiguration.isAdsDisabled else { return }
        GADMobileAds.sharedInstance().requestConfiguration.testDeviceIdentifiers = nil
        GADMobileAds.sharedInstance().start { [weak self] _ in
            Task { @MainActor in self?.requestUMPThenPreload() }
        }
    }

    private func requestUMPThenPreload() {
        let params = UMPRequestParameters()
        params.tagForUnderAgeOfConsent = false
        UMPConsentInformation.shared.requestConsentInfo(with: params) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if UMPConsentInformation.shared.isConsentFormAvailable,
                   UMPConsentInformation.shared.isConsentFormRequired,
                   let vc = Self.topViewController() {
                    UMPConsentInformation.shared.loadAndPresent(ifRequiredFrom: vc) { [weak self] _ in
                        Task { @MainActor in self?.preloadAll() }
                    }
                } else {
                    self.preloadAll()
                }
            }
        }
    }

    private func preloadAll() {
        loadInterstitial()
        preloadRewarded()
    }

    private func loadInterstitial() {
        let req = Self.makeRequest()
        GADInterstitialAd.load(withAdUnitID: AdsConfiguration.interstitialId, request: req) { [weak self] ad, err in
            Task { @MainActor in
                guard let ad else { return }   // silent skip on err
                ad.fullScreenContentDelegate = self
                self?.interstitial = ad
            }
        }
    }

    func preloadRewarded() {
        guard !AdsConfiguration.isAdsDisabled else { return }
        let req = Self.makeRequest()
        GADRewardedAd.load(withAdUnitID: AdsConfiguration.rewardedId, request: req) { [weak self] ad, err in
            Task { @MainActor in
                guard let ad else { return }
                ad.fullScreenContentDelegate = self
                self?.rewarded = ad
            }
        }
    }

    func showRewarded(onGrant: @escaping RewardGrant) {
        guard !AdsConfiguration.isAdsDisabled, let rewarded, let vc = Self.topViewController() else { return }
        pendingGrant = onGrant
        rewarded.present(fromRootViewController: vc) { [weak self] in
            // "userEarnedReward" closure fires HERE per v11 API
            self?.pendingGrant?()
            self?.pendingGrant = nil
        }
    }

    func maybeShowInterstitial() {
        guard !AdsConfiguration.isAdsDisabled, let interstitial, let vc = Self.topViewController() else { return }
        interstitial.present(fromRootViewController: vc)
        // Phase 07 AppModel advances counters + reload via delegate
    }

    // MARK: GADFullScreenContentDelegate
    nonisolated func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        Task { @MainActor in
            if ad is GADInterstitialAd { interstitial = nil; loadInterstitial() }
            if ad is GADRewardedAd { rewarded = nil; preloadRewarded() }
        }
    }

    // MARK: GADBannerViewDelegate
    nonisolated func bannerViewDidReceiveAd(_ bannerView: GADBannerView) {
        Task { @MainActor in bannerReady = true }
    }
    nonisolated func bannerView(_ bannerView: GADBannerView, didFailToReceiveAdWithError error: Error) {
        Task { @MainActor in bannerReady = false }
    }

    // MARK: Helpers
    private static func makeRequest() -> GADRequest {
        let req = GADRequest()
        if ATTRequester.shouldUseNonPersonalizedAds() {
            req.extras = GADExtras(); req.extras?.additionalParameters = ["npa": "1"]
        }
        return req
    }

    static func topViewController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.keyWindow?.rootViewController else { return nil }
        var top = root
        while let presented = top.presentedViewController { top = presented }
        return top
    }
}
```

> ⚠️ v11 API surface: confirm exact `present` signatures + `userEarnedReward` closure at implementation time — Google has shifted between `GADRewardedAdDelegate` (v9) and the closure-on-present model (v10+). The skeleton assumes v11 closure-on-present; if v11 still uses `GADRewardedAdDelegate.userEarnedReward(_:_:)`, swap to delegate-based grant (still grant-in-callback).

## Implementation Steps
1. Create `AdsManager.swift`.
2. Implement `start()` + UMP flow + preload all.
3. Implement `loadInterstitial` / `preloadRewarded` / `showRewarded` / `maybeShowInterstitial`.
4. Implement delegates + `topViewController()` + `makeRequest()` (NPA extra).
5. Wire kill-switch early-return in every public method.
6. Build green (app target only).
7. Tests 89/89 (mock still in use).
8. Manual smoke (DEBUG test IDs on simulator): `ads.start()` → confirm UMP/SDK logs; wait for interstitial+rewarded preload.
9. Commit: `feat(ads): implement AdsManager (init, preload, UMP, NPA) [phase-05]`.

## todo list
- [ ] `AdsManager.swift` skeleton (@Observable, NSObject for delegates)
- [ ] `start()` + `requestUMPThenPreload()`
- [ ] `loadInterstitial` / `preloadRewarded`
- [ ] `showRewarded` (grant-in-callback)
- [ ] `maybeShowInterstitial`
- [ ] `GADFullScreenContentDelegate.adDidDismissFullScreenContent` (reload)
- [ ] `GADBannerViewDelegate` bannerReady flips
- [ ] `topViewController()` helper
- [ ] `makeRequest()` with NPA extra
- [ ] Kill-switch short-circuits
- [ ] Build green
- [ ] Tests 89/89
- [ ] Manual smoke on sim
- [ ] Commit

## Success Criteria
- Build green; SDK imported + used in one file only.
- All public methods are no-ops under `-uitest-reset`.
- Sim run: SDK init succeeds; UMP form skips (no GDPR region on sim); preload completes without error.
- Reward grant closure fires exactly once per ad watch (manual verify with test ad).

## Risk Assessment
| Risk | Mitigation |
|---|---|
| v11 API drift (delegate vs closure) | Check GoogleMobileAds header at impl time; refactor accordingly. Skeleton is directionally correct. |
| Reward granted twice if dismiss + earned both fire | `pendingGrant` is single-shot (set to nil after fire). |
| UMP form never returns on sim (regional) | Acceptable on sim; real-device test Phase 09. |
| Top-VC is nil during app launch race | Public methods guard on `topViewController() != nil` else silent skip. |
| `nonisolated` delegate mismatch with `@MainActor` default isolation | Mark delegates `nonisolated` explicitly + hop to MainActor via Task (skeleton shows pattern). |
| Preload never completes (network) | Silent; UI surfaces check `interstitial != nil` / `rewarded != nil` before showing. |

## Security Considerations
- No secrets in code.
- NPA respects user's ATT choice; no tracking bypassed.

## Next steps
→ Phase 06 (Banner representable + HomeView) AND Phase 07 (Interstitial AppModel) AND Phase 08 (Rewarded UI) — all depend on Phase 05, mutually parallel-safe.
