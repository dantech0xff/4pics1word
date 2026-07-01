import GoogleMobileAds
import Observation
import UIKit
import UserMessagingPlatform

/// Concrete `AdsManaging`. Owns GAD interstitial/rewarded/banner instances, runs UMP consent,
/// preloads full-screen ads, and applies the NPA (non-personalized-ads) extra until ATT is
/// authorized. All public methods no-op under `AdsConfiguration.isAdsDisabled`.
///
/// Reward grant rule: `showRewarded`'s `onGrant` closure is invoked from the SDK's
/// user-earned-reward callback (NOT from ad-did-dismiss) — so killing the app mid-ad can never
/// grant a free reward.
@MainActor
@Observable
final class AdsManager: NSObject, AdsManaging, GADFullScreenContentDelegate, GADBannerViewDelegate {
    private(set) var bannerReady = false
    private var interstitial: GADInterstitialAd?
    private var rewarded: GADRewardedAd?

    override init() {
        super.init()
    }

    // MARK: AdsManaging

    func start() {
        guard !AdsConfiguration.isAdsDisabled else { return }
        GADMobileAds.sharedInstance().start { [weak self] _ in
            Task { @MainActor in self?.requestUmpThenPreload() }
        }
    }

    func preloadRewarded() {
        guard !AdsConfiguration.isAdsDisabled else { return }
        let req = Self.makeRequest()
        GADRewardedAd.load(withAdUnitID: AdsConfiguration.rewardedId, request: req) { [weak self] ad, _ in
            Task { @MainActor in
                guard let ad else { return }
                ad.fullScreenContentDelegate = self
                self?.rewarded = ad
            }
        }
    }

    func showRewarded(onGrant: @escaping RewardGrant) {
        guard !AdsConfiguration.isAdsDisabled,
              let rewarded,
              let vc = Self.topViewController() else { return }
        rewarded.present(fromRootViewController: vc) {
            // userDidEarnRewardHandler — fires when the user earned the reward.
            onGrant()
        }
    }

    func maybeShowInterstitial() {
        guard !AdsConfiguration.isAdsDisabled,
              let interstitial,
              let vc = Self.topViewController() else { return }
        interstitial.present(fromRootViewController: vc)
    }

    // MARK: GADFullScreenContentDelegate (called on main thread by SDK contract)

    nonisolated func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            if ad is GADInterstitialAd { self.interstitial = nil; self.loadInterstitial() }
            if ad is GADRewardedAd { self.rewarded = nil; self.preloadRewarded() }
        }
    }

    // MARK: GADBannerViewDelegate (called on main thread by SDK contract)

    nonisolated func bannerViewDidReceiveAd(_ bannerView: GADBannerView) {
        Task { @MainActor [weak self] in self?.bannerReady = true }
    }

    nonisolated func bannerView(_ bannerView: GADBannerView, didFailToReceiveAdWithError error: any Error) {
        Task { @MainActor [weak self] in self?.bannerReady = false }
    }

    // MARK: Internals

    private func requestUmpThenPreload() {
        let params = UMPRequestParameters()
        params.tagForUnderAgeOfConsent = false
        UMPConsentInformation.sharedInstance.requestConsentInfoUpdate(with: params) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard let vc = Self.topViewController() else { self.preloadAll(); return }
                UMPConsentForm.loadAndPresentIfRequired(from: vc) { [weak self] _ in
                    Task { @MainActor in self?.preloadAll() }
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
        GADInterstitialAd.load(withAdUnitID: AdsConfiguration.interstitialId, request: req) { [weak self] ad, _ in
            Task { @MainActor in
                guard let ad else { return }
                ad.fullScreenContentDelegate = self
                self?.interstitial = ad
            }
        }
    }

    /// Builds a `GADRequest` with the NPA extra attached until ATT is authorized, so the banner
    /// still fills (lower CPM) instead of returning no-fill.
    static func makeRequest() -> GADRequest {
        let req = GADRequest()
        if ATTRequester.shouldUseNonPersonalizedAds() {
            let extras = GADExtras()
            extras.additionalParameters = ["npa": "1"]
            req.register(extras)
        }
        return req
    }

    /// Resolves the topmost view controller for presenting full-screen ads. Walks the
    /// presented-VC chain from the key window's root.
    static func topViewController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let root = scene.keyWindow?.rootViewController else { return nil }
        var top = root
        while let presented = top.presentedViewController { top = presented }
        return top
    }
}
