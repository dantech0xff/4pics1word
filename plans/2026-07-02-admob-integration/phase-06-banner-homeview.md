# Phase 06 — Banner Representable + HomeView Wiring

## Context links
- Parent plan: `../plan.md`
- Dependency: Phase 05 (AdsManager), Phase 03 (AdsConfiguration).
- Brainstorm: §"Brutal honesty" item 10.
- Source: `4pics1word/Views/HomeView.swift` (L8 VStack), new `4pics1word/Ads/BannerHostView.swift`.

## Overview
- Date: 2026-07-02
- Description: SwiftUI bridge for adaptive `GADBannerView`. Placed at bottom of `HomeView`, gated by `model.phase == .home`.
- Priority: P1
- Implementation status: pending
- Review status: pending

## Key Insights
- **`UIViewControllerRepresentable` not raw `UIViewRepresentable`** — adaptive banners need a hosting VC for safe-area/keyboard/inset coordination (Google's official SwiftUI sample). Project already bridges UIKit (`UIImage`, `Feedback`).
- **Adaptive banner size** — `GADCurrentOrientationAnchoredAdaptiveBannerAdSizeWithWidth(width)` for full-width bottom banners. Computed in `makeUIViewController` from VC width.
- **Phase gate** — banner visible ONLY when `model.phase == .home` (locked decision). Settings/Credits are pushed inside the same NavigationStack, so the banner naturally hides when those push (HomeView unmounted). Verify no accidental persistence on Settings/Credits.
- **Kill-switch** — under `-uitest-reset`, render a transparent 50pt spacer (preserves layout) instead of the real banner.
- **Lazy init** — banner View created by HomeView body; `GADBannerView.load()` happens once per HomeView appearance (acceptable; AdMob dedupes rapid loads).
- **`@MainActor` default** — representable methods run on main already.

## Requirements
1. `BannerHostView: UIViewControllerRepresentable` exposes `init(ads:)`.
2. Uses adaptive banner size based on parent VC width.
3. No-op spacer under `-uitest-reset`.
4. `HomeView` shows it at the bottom of the root VStack (`HomeView.swift:8`), gated by `model.phase == .home`.
5. Layout: above safe-area; pushes existing content up by banner height (~50pt standard, 60pt adaptive edge).
6. All 89 tests pass; banner not exercised in unit tests (UI-test territory).

## Architecture

### `4pics1word/Ads/BannerHostView.swift`
```swift
import GoogleMobileAds
import SwiftUI
import UIKit

struct BannerHostView: UIViewControllerRepresentable {
    let ads: AdsManager   // Phase 05; owned by AppModel

    func makeUIViewController(context: Context) -> UIViewController {
        let host = UIViewController()
        guard !AdsConfiguration.isAdsDisabled else {
            host.view.frame = .init(x: 0, y: 0, width: 320, height: 50)
            host.view.isUserInteractionEnabled = false
            return host
        }
        let banner = GADBannerView(adSize: GADPortraitAnchoredAdaptiveBannerAdSizeWithWidth(host.view.bounds.width))
        banner.adUnitID = AdsConfiguration.bannerId
        banner.rootViewController = host
        banner.delegate = ads
        host.view.addSubview(banner)
        banner.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            banner.centerXAnchor.constraint(equalTo: host.view.centerXAnchor),
            banner.bottomAnchor.constraint(equalTo: host.view.bottomAnchor)
        ])
        banner.load(AdsManager.makeRequestPublic())  // expose makeRequest as static if private
        return host
    }

    func updateUIViewController(_ vc: UIViewController, context: Context) {}
}
```

> ⚠️ Make `AdsManager.makeRequest()` static (or duplicate) so the representable can build requests without an instance. Refactor Phase 05 helper to `static func makeRequest()`.

### `HomeView.swift` — bottom insertion
```swift
var body: some View {
    VStack(spacing: 24) {
        toolbar
        Spacer()
        titleBlock
        Spacer()
        playButton
        progressLabel
        Spacer()
        Spacer()
        if !AdsConfiguration.isAdsDisabled {
            BannerHostView(ads: model.ads)
                .frame(height: 50)   // adaptive cap; system sizes real ad
        }
    }
    .padding(.horizontal, 24)
    .navigationBarHidden(true)
}
```
`model.ads` is injected into AppModel in Phase 07; here it's assumed present. Until Phase 07, gate behind `if model.ads != nil` or compile-flag stub.

## Implementation Steps
1. Refactor `AdsManager.makeRequest()` to `static` (if not already).
2. Write `BannerHostView.swift`.
3. Modify `HomeView.body` bottom (L8–17 region) — add banner + spacing.
4. Build green.
5. Manual sim: HomeView shows test banner at bottom; push Settings → banner gone; pop → returns.
6. Run UI tests under `-uitest-reset` — banner absent; layout stable.
7. Commit: `feat(ads): banner representable + HomeView bottom placement [phase-06]`.

## todo list
- [ ] Make `makeRequest()` static on AdsManager
- [ ] Write `BannerHostView.swift` (UIViewControllerRepresentable)
- [ ] Insert banner into `HomeView.body`
- [ ] Kill-switch spacer path verified
- [ ] Build green
- [ ] Manual sim verify (banner shows, phase gating works)
- [ ] UI tests pass under `-uitest-reset`
- [ ] Commit

## Success Criteria
- Test banner appears at HomeView bottom in DEBUG sim.
- Banner hides when navigating to Settings/Credits (push).
- Banner never appears during gameplay phases.
- Under `-uitest-reset`, no banner, no layout shift.

## Risk Assessment
| Risk | Mitigation |
|---|---|
| Adaptive banner width = 0 at makeUIViewController time | Use `GADPortraitAnchoredAdaptiveBannerAdSizeWithWidth(UIScreen.main.bounds.width)` as fallback if host.view.bounds is zero. |
| Banner overlaps with safe-area / home indicator | Pin to `safeAreaLayoutGuide.bottomAnchor` instead of view bottom. |
| Banner persists across push to Settings (representable lifecycle) | HomeView unmounts on push → representable deallocates. Verify; if not, gate with `if model.phase == .home` is implicit via HomeView lifecycle. |
| Layout jumps when banner fills asynchronously | Pre-reserve 50pt frame; banner fades in. Acceptable. |
| Banner delegate method names drift in v11 | Check headers; `GADBannerViewDelegate` is stable. |

## Security Considerations
None.

## Next steps
→ Phase 07 (Interstitial AppModel integration) — parallel-safe.
