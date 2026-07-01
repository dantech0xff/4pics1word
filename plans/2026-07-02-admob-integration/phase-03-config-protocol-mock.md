# Phase 03 — AdsConfiguration + AdsManaging Protocol + Mock

## Context links
- Parent plan: `../plan.md`
- Dependency: none (parallel-safe with Phase 02).
- Brainstorm: §"Recommended architecture" + §"Testability strategy".
- Source: app target (`4pics1word/`), unit-test target (`4pics1wordTests/`).

## Overview
- Date: 2026-07-02
- Description: Create the test seam BEFORE the real AdsManager. `AdsConfiguration` holds test-vs-prod IDs and the kill-switch. `AdsManaging` is the protocol AppModel will depend on. `MockAdsManager` is the test double.
- Priority: P1
- Implementation status: pending
- Review status: pending

## Key Insights
- **Build the seam first.** Then AppModel can be wired to depend on `AdsManaging` (Phase 07) without the SDK-dependent `AdsManager` existing yet.
- **TEST IDs ONLY (2026-07-02 revision).** No AdMob account → use Google's official test IDs in BOTH Debug and Release. `#if DEBUG` split removed (would be dead branch). When real account lands, reintroduce split.
- **Kill-switch reads `-uitest-reset` launch arg at runtime** — same flag `_pics1wordApp.init` already uses to wipe UserDefaults (`_pics1wordApp.swift:13`). Reuses the existing convention; no new launch arg.
- **Protocol returns `@MainActor`-isolated closures** for reward grants — matches project default isolation (`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`).
- **Mock lives in unit-test target**, not app — keeps test-only types out of the shipping binary. `import Testing` already available there.
- **Google's official test IDs** (well-known, used in BOTH configs now):
  - App: `ca-app-pub-3940256099942544~1458002511`
  - Banner: `ca-app-pub-3940256099942544/2934735716`
  - Interstitial: `ca-app-pub-3940256099942544/4411468910`
  - Rewarded: `ca-app-pub-3940256099942544/1712485313`

## Requirements
1. `AdsConfiguration` exposes: `appId`, `bannerId`, `interstitialId`, `rewardedId`, `isAdsDisabled`. Resolved via `#if DEBUG` + launch arg.
2. `AdsManaging` protocol declares: `start()`, `preloadRewarded()`, `showRewarded(onGrant:)`, `maybeShowInterstitial()`, `var bannerReady: Bool { get }`.
3. `MockAdsManager` in `4pics1wordTests/` implements the protocol; records call counts; exposes test hooks `fireGrant()` and `simulateInterstitialShown()`.
4. None of these files import `GoogleMobileAds` — keeps the seam SDK-free at this layer.
5. All 89 tests pass (mock not yet injected into AppModel — Phase 07).

## Architecture

### `4pics1word/Ads/AdsConfiguration.swift`
```swift
import Foundation

enum AdsConfiguration {
    static var isAdsDisabled: Bool {
        CommandLine.arguments.contains("-uitest-reset")
    }

    // ⚠️ TEST IDs throughout (no AdMob account yet). Cannot ship to App Store in this state.
    // When real account is registered, swap these for prod IDs (and reintroduce #if DEBUG split).
    static let appId          = "ca-app-pub-3940256099942544~1458002511"
    static let bannerId       = "ca-app-pub-3940256099942544/2934735716"
    static let interstitialId = "ca-app-pub-3940256099942544/4411468910"
    static let rewardedId     = "ca-app-pub-3940256099942544/1712485313"
}
```

### `4pics1word/Ads/AdsManaging.swift`
```swift
import Foundation

typealias RewardGrant = () -> Void

protocol AdsManaging: AnyObject {
    func start()
    func preloadRewarded()
    func showRewarded(onGrant: @escaping RewardGrant)
    func maybeShowInterstitial()
    var bannerReady: Bool { get }
}
```
(`AnyObject` — Phase 05 `AdsManager` is `@Observable final class`; mock also reference type.)

### `4pics1wordTests/MockAdsManager.swift`
```swift
import Foundation
@testable import _pics1word

@MainActor
final class MockAdsManager: AdsManaging {
    private(set) var startCallCount = 0
    private(set) var preloadCallCount = 0
    private(set) var showRewardedCallCount = 0
    private(set) var interstitialCallCount = 0
    var bannerReady: Bool = false

    private var pendingGrant: RewardGrant?

    func start() { startCallCount += 1 }
    func preloadRewarded() { preloadCallCount += 1 }
    func showRewarded(onGrant: @escaping RewardGrant) {
        showRewardedCallCount += 1
        pendingGrant = onGrant
    }
    func maybeShowInterstitial() { interstitialCallCount += 1 }

    // Test hooks:
    func fireGrant() { pendingGrant?(); pendingGrant = nil }
    func simulateInterstitialShown() { /* for Phase 09 frequency assertions */ }
}
```

## Implementation Steps
1. Create folder `4pics1word/Ads/` (file-synchronized group auto-registers).
2. Write `AdsConfiguration.swift`.
3. Write `AdsManaging.swift`.
4. Write `4pics1wordTests/MockAdsManager.swift`.
5. Build green (mock unused but compiles).
6. Tests 89/89 unchanged.
7. Commit: `feat(ads): add AdsConfiguration, AdsManaging protocol, MockAdsManager [phase-03]`.

## todo list
- [ ] Create `4pics1word/Ads/` folder
- [ ] `AdsConfiguration.swift` with test IDs (no #if DEBUG split)
- [ ] `AdsManaging.swift` protocol + `RewardGrant` typealias
- [ ] `MockAdsManager.swift` in test target
- [ ] Build green
- [ ] Tests 89/89
- [ ] Commit

## Success Criteria
- All 3 files compile; no SDK imports.
- Mock passes conformance to `AdsManaging`.
- `AdsConfiguration.isAdsDisabled` returns true under `-uitest-reset` (verify via test in Phase 09).

## Risk Assessment
| Risk | Mitigation |
|---|---|
| App ships with test IDs → Apple rejects, $0 revenue | Submit-blocked by design (Phase 09 submission checklist gates this). Swap is config-only when real IDs arrive. |
| Protocol signature drift vs Phase 05 needs | Iterate freely — only the mock depends on it right now. |
| `@MainActor` on mock causes test isolation issues | Project is `MainActor` default; Swift Testing structs are `@MainActor` by default — matches. |

## Security Considerations
None — IDs are public. `-uitest-reset` mechanism already exists for state wipe.

## Next steps
→ Phase 04 (ATTRequester + UMP) — depends on Phase 02.
