import Foundation

/// Ad configuration: ad-unit IDs + global kill-switch.
///
/// ⚠️ TEST IDs ONLY (no AdMob account registered yet). Both Debug and Release use Google's
/// official sample IDs. This configuration CANNOT ship to the App Store — Apple rejects test
/// ads and AdMob pays $0. When a real account + ad units are registered, swap these four
/// constants (and add `SKAdNetworkItems` to Info.plist). No architecture change required.
enum AdsConfiguration {
    /// True when launched with the `-uitest-reset` flag (UI tests). All ad surfaces render
    /// as inert placeholders / no-ops, and no SDK calls are made. Mirrors the flag
    /// `_pics1wordApp.init` already uses to wipe UserDefaults.
    static var isAdsDisabled: Bool {
        CommandLine.arguments.contains("-uitest-reset")
    }

    // Google's documented sample App ID + ad-unit IDs:
    // https://developers.google.com/admob/ios/test-ads
    static let appId          = "ca-app-pub-3940256099942544~1458002511"
    static let bannerId       = "ca-app-pub-3940256099942544/2934735716"
    static let interstitialId = "ca-app-pub-3940256099942544/4411468910"
    static let rewardedId     = "ca-app-pub-3940256099942544/1712485313"
}
