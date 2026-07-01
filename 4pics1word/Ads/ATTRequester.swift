import AppTrackingTransparency
import Foundation

/// Thin wrapper around `ATTrackingManager` plus an NPA (non-personalized-ads) predicate.
///
/// ATT prompt timing (locked decision): after the first ever puzzle solve, gated by
/// `Progress.hasSeenAttPrompt`. `AppModel.handleSolved` sets that flag + flips
/// `shouldShowAttExplainer`; `AppRootView` presents `ATTExplainerView`, whose "Continue"
/// button calls `ATTRequester.requestIfNeeded`.
///
/// While status is `.notDetermined` (or denied/restricted), all ad requests carry the
/// `npa=1` extra so the banner still fills (lower CPM) instead of returning no-fill.
@MainActor
enum ATTRequester {
    static var status: ATTrackingManager.AuthorizationStatus {
        ATTrackingManager.trackingAuthorizationStatus
    }

    /// True when we have NOT yet been authorized for tracking. Callers attach `npa=1`.
    static func shouldUseNonPersonalizedAds() -> Bool {
        status != .authorized
    }

    /// Fire the system ATT prompt once. No-op if already determined. `completion` runs on
    /// the main actor after the user responds (or immediately if already determined).
    static func requestIfNeeded(then completion: @escaping () -> Void) {
        guard status == .notDetermined else { completion(); return }
        ATTrackingManager.requestTrackingAuthorization { _ in
            Task { @MainActor in completion() }
        }
    }
}
