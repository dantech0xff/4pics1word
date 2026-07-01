import GoogleMobileAds
import SwiftUI
import UIKit

/// SwiftUI bridge for an adaptive anchored `GADBannerView`. Uses a `UIViewControllerRepresentable`
/// (not raw `UIViewRepresentable`) so the banner's safe-area/inset handling is coordinated by a
/// hosting view controller. Shown only on HomeView (locked decision: banner never during gameplay).
///
/// Under `AdsConfiguration.isAdsDisabled` the host view controller is empty — HomeView gates the
/// whole representable with an `if` so it isn't even composed in UI-test runs.
struct BannerHostView: UIViewControllerRepresentable {
    let ads: AdsManager

    func makeUIViewController(context: Context) -> UIViewController {
        let host = UIViewController()
        host.view.accessibilityIdentifier = "adBanner"
        guard !AdsConfiguration.isAdsDisabled else { return host }

        // Adaptive banner size from the available width (falls back to screen width before layout).
        let width = host.view.bounds.width > 0 ? host.view.bounds.width : UIScreen.main.bounds.width
        let banner = GADBannerView(adSize: GADCurrentOrientationAnchoredAdaptiveBannerAdSizeWithWidth(width))
        banner.adUnitID = AdsConfiguration.bannerId
        banner.rootViewController = host
        banner.delegate = ads
        banner.translatesAutoresizingMaskIntoConstraints = false
        host.view.addSubview(banner)
        NSLayoutConstraint.activate([
            banner.centerXAnchor.constraint(equalTo: host.view.centerXAnchor),
            banner.bottomAnchor.constraint(equalTo: host.view.safeAreaLayoutGuide.bottomAnchor),
        ])
        banner.load(AdsManager.makeRequest())
        return host
    }

    func updateUIViewController(_ vc: UIViewController, context: Context) {
        // No dynamic updates needed — banner auto-refreshes on its own cadence.
    }
}
