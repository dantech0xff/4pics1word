import Foundation

/// Closure invoked exactly once when a rewarded ad's earn event fires. Implementations MUST
/// persist any state mutation synchronously (defeats the kill-app-mid-ad exploit).
typealias RewardGrant = () -> Void

/// Ads subsystem seam. `AppModel` depends on this protocol, not on the concrete
/// `AdsManager` — keeps the domain model SDK-free and unit-testable via `MockAdsManager`.
@MainActor
protocol AdsManaging: AnyObject {
    /// Initialize the SDK, run UMP consent, and preload interstitial + rewarded. Safe to call
    /// once at app launch; no-op under `AdsConfiguration.isAdsDisabled`.
    func start()

    /// (Re)load a rewarded ad so it is ready for the next `showRewarded`. Called on app start
    /// and again from the ad-did-dismiss delegate.
    func preloadRewarded()

    /// Present the rewarded ad from the top view controller. `onGrant` fires exactly once when
    /// the SDK reports the user earned the reward (NOT on dismiss).
    func showRewarded(onGrant: @escaping RewardGrant)

    /// Present an interstitial if one is loaded. Cadence/cooldown gating lives in `AppModel`
    /// (testable there); this method only checks ad-readiness.
    func maybeShowInterstitial()

    /// True when a banner ad has been received and is renderable. Drives HomeView visibility.
    var bannerReady: Bool { get }
}
