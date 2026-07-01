import Foundation
@testable import _pics1word

/// Test double for `AdsManaging`. Records call counts and exposes hooks to drive SDK callbacks
/// (reward grant, banner-ready flip) deterministically from unit tests. Never touches the SDK.
@MainActor
final class MockAdsManager: AdsManaging {
    private(set) var startCallCount = 0
    private(set) var preloadRewardedCallCount = 0
    private(set) var showRewardedCallCount = 0
    private(set) var maybeShowInterstitialCallCount = 0
    private(set) var interstitialsShown = 0
    var bannerReady = false

    private var pendingGrant: RewardGrant?

    func start() { startCallCount += 1 }
    func preloadRewarded() { preloadRewardedCallCount += 1 }

    func showRewarded(onGrant: @escaping RewardGrant) {
        showRewardedCallCount += 1
        pendingGrant = onGrant
    }

    func maybeShowInterstitial() {
        maybeShowInterstitialCallCount += 1
        interstitialsShown += 1
    }

    /// Simulate the SDK firing its reward-earned callback. Idempotent: a second call is a no-op.
    func fireGrant() {
        pendingGrant?()
        pendingGrant = nil
    }

    /// Test hook: pretend a banner ad just loaded.
    func makeBannerReady() { bannerReady = true }
}
