# Phase 04 — ATTRequester + UMP + ATT Explainer Sheet

## Context links
- Parent plan: `../plan.md`
- Dependency: Phase 02 (Progress.hasSeenAttPrompt).
- Brainstorm: §"Brutal honesty" items 2, 3.
- Source: `4pics1word/Views/AppRootView.swift` (L32 `.task`), new files.

## Overview
- Date: 2026-07-02
- Description: Wrap `ATTrackingManager` + UMP consent flow behind `ATTRequester`. Pre-prompt explainer sheet ("Why we ask") fires once after first solve, then the system ATT prompt.
- Priority: P1
- Implementation status: pending
- Review status: pending

## Key Insights
- **ATT timing = after first solve** (locked decision). Trigger from `AppModel.handleSolved` when `!progress.hasSeenAttPrompt`. Set the flag synchronously BEFORE presenting, to prevent re-fire on multi-solve edge cases.
- **Pre-prompt explainer lifts opt-in ~30%** (Google's data). One-shot sheet with value-framed copy + "Allow" / "Ask me later" (no — can't be — there is no later; this IS the explainer before the system prompt).
- **UMP = required for EEA/UK** regardless of ATT (GoogleMobileAds enforces; calls will return no-fill without consent in those regions). Use `UMPRequestParameters` + `UMPConsentInformation.requestConsentInfo(with:)` + `loadAndPresentIfRequiredFromViewController`.
- **NPA fallback until ATT resolved**: while `ATTrackingManager.trackingAuthorizationStatus == .notDetermined`, all `GADRequest` get `extras["npa"] = "1"`. Banner still fills (lower CPM). Phase 05 wires this.
- **MainActor default** — `ATTrackingManager.requestTrackingAuthorization` completion + UMP completion handlers arrive on main; mark the requester `@MainActor`.
- **Explainer copy is user-facing** — must be honest (no dark patterns). Apple rejects misleading descriptions.

## Requirements
1. `ATTRequester` exposes: `var status: ATTrackingManager.AuthorizationStatus`, `func requestIfNeeded(then:)`, `func shouldUseNonPersonalizedAds() -> Bool`.
2. UMP request runs on app start (inside `AdsManager.start()` — wired in Phase 05).
3. `ATTExplainerView` SwiftUI sheet: 1 explainer paragraph + "Continue" button → triggers system ATT prompt.
4. `Progress.hasSeenAttPrompt` flips to `true` before the explainer sheet is presented (one-shot guard).
5. After ATT prompt resolves, NPA flag recomputes (callers re-read `shouldUseNonPersonalizedAds`).
6. All 89 tests pass (no callers yet).

## Architecture

### `4pics1word/Ads/ATTRequester.swift`
```swift
import AppTrackingTransparency
import Foundation

@MainActor
enum ATTRequester {
    static var status: ATTrackingManager.AuthorizationStatus {
        ATTrackingManager.trackingAuthorizationStatus
    }

    static var hasPrompted: Bool { status != .notDetermined }

    /// True while status is unknown or denied — caller should attach `npa=1` extra.
    static func shouldUseNonPersonalizedAds() -> Bool {
        switch status {
        case .authorized: return false
        case .notDetermined, .denied, .restricted, .notSupported: return true
        @unknown default: return true
        }
    }

    static func requestIfNeeded(then completion: @escaping () -> Void) {
        guard status == .notDetermined else { completion(); return }
        ATTrackingManager.requestTrackingAuthorization { _ in
            Task { @MainActor in completion() }
        }
    }
}
```

### `4pics1word/Views/ATTExplainerView.swift`
```swift
import SwiftUI

struct ATTExplainerView: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.accentColor)
            Text("Keep the Game Free")
                .font(.title.weight(.bold))
            Text("4 Pics 1 Word is free because of ads. Allowing tracking helps advertisers show you more relevant ads — this keeps our game free for everyone. No personal data is sold.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Button("Continue") { onContinue() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
        }
        .padding(28)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}
```

### UMP — wired inside AdsManager.start() in Phase 05 (preview)
```swift
let params = UMPRequestParameters()
params.tagForUnderAgeOfConsent = false
UMPConsentInformation.shared.requestConsentInfo(with: params) { _ in
    Task { @MainActor in
        if UMPConsentInformation.shared.isConsentFormAvailable,
           UMPConsentInformation.shared.isConsentFormRequired {
            // present from top VC (Phase 05 helper)
        }
    }
}
```

## Implementation Steps
1. Write `ATTRequester.swift` (enum, no instance state).
2. Write `ATTExplainerView.swift`.
3. Build green.
4. Tests 89/89 (no callers).
5. Commit: `feat(ads): ATTRequester + UMP sketch + ATT explainer sheet [phase-04]`.
6. **Wire-up of explainer → AppRootView happens in Phase 07** (AppModel exposes `shouldShowAttExplainer` derived from `handleSolved` + flag).

## todo list
- [ ] `ATTRequester.swift` (status, NPA predicate, requestIfNeeded)
- [ ] `ATTExplainerView.swift`
- [ ] (Preview) UMP params — actual call deferred to Phase 05
- [ ] Build green
- [ ] Tests 89/89
- [ ] Commit

## Success Criteria
- `ATTRequester.shouldUseNonPersonalizedAds()` returns `true` pre-prompt, `false` post-authorized.
- Explainer sheet compiles + previews in Xcode canvas.
- Project compiles with `import AppTrackingTransparency` (iOS 14+, fine).

## Risk Assessment
| Risk | Mitigation |
|---|---|
| ATT prompt shows before explainer if `handleSolved` fires too eagerly | Flag is set in AppModel synchronously BEFORE sheet appears; AppRootView reads `model.shouldShowAttExplainer` (Phase 07). |
| UMP form presentable VC resolution fails | Phase 05 top-VC helper walks `presentedViewController` chain. |
| ATT copy rejected by review | Keep value-framed, no manipulation. Reference Apple HIG sample wording. |
| iOS simulator fakes ATT status | Real device test in Phase 09 (or accept sim's default `.notDetermined`). |

## Security Considerations
- ATT prompt is OS-level — user choice is final, can't be coerced.
- UMP consent persists per Google's SDK; we don't store it.

## Next steps
→ Phase 05 (AdsManager implementation) — depends on 01, 03, 04.
