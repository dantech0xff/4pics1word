# Phase 08 — Rewarded UI Surfaces (HomeView + Hint Alert)

## Context links
- Parent plan: `../plan.md`
- Dependency: Phase 07 (AppModel.grantRewardCoins + ads injection).
- Brainstorm: §"Key flows" Reward + resolved open Q1 ("yes, include reward-from-hint-alert").
- Source: `4pics1word/Views/HomeView.swift` (L8), `4pics1word/Views/GameView.swift` (hint alert — locate at impl time).

## Overview
- Date: 2026-07-02
- Description: Surface rewarded video at two friction points: (a) HomeView "Free coins" button shown when balance < HintCost.remove (90); (b) hint-insufficient alert in GameView with "Watch ad for +50" action.
- Priority: P1
- Implementation status: pending
- Review status: pending

## Key Insights
- **Threshold-gated visibility** — HomeView "Free coins" button shown only when `progress.coins < HintCost.remove` (90). Avoids button-clutter when balance is healthy (recommended threshold from brainstorm open Q4).
- **Hint-insufficient alert** — when player taps a hint they can't afford, current behavior is presumably a no-op or static "not enough coins" message. Add an `Alert` action "Watch ad (+50)" → `ads.showRewarded { model.grantRewardCoins(50) }`.
- **Grant closure** — passed to `AdsManager.showRewarded(onGrant:)`. Fires inside SDK callback. AppModel.grantRewardCoins persists synchronously.
- **No double-action** — once ad starts, disable the trigger button (per-ad state) to prevent re-entrancy.
- **Kill-switch** — under `-uitest-reset`, hide the button entirely (mock's `showRewarded` still callable for tests but real UI should hide).
- **Locate GameView hint alert** at impl time — search `GameView.swift` for hint Button + alert state.

## Requirements
1. HomeView shows "Free coins (+50 via ad)" button when `model.progress.coins < HintCost.remove`.
2. Button hidden when balance ≥ 90 OR `-uitest-reset` active.
3. GameView hint-insufficient alert exposes "Watch ad (+50)" action.
4. Both call `model.ads.showRewarded { model.grantRewardCoins(50) }`.
5. Reward amount centralized: `Economy.rewardedAdPayout = 50` (new const; co-locate with `Economy.reward`).
6. Button disabled while ad in flight (track via local `@State var adInFlight: Bool = false`).
7. All tests pass.

## Architecture

### `Economy` const
```swift
enum Economy {
    static let startingCoins: Int = 100
    static let rewardedAdPayout: Int = 50    // NEW

    static func reward(forTier tier: Int) -> Int { 25 + 5 * tier }
}
```

### HomeView — "Free coins" button
```swift
@ViewBuilder
private var freeCoinsButton: some View {
    if !AdsConfiguration.isAdsDisabled && model.progress.coins < HintCost.remove {
        Button {
            adInFlight = true
            model.ads.showRewarded {
                model.grantRewardCoins(Economy.rewardedAdPayout)
                adInFlight = false
            }
        } label: {
            Label("Free Coins (+\(Economy.rewardedAdPayout))", systemImage: "play.rectangle.fill")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
        .disabled(adInFlight)
    }
}
```
Insert between `progressLabel` and bottom Spacers in `HomeView.body` (L14 region).

### GameView — hint-insufficient alert
Locate the existing hint-cost-can't-afford path. If absent, add:
```swift
.alert("Not enough coins", isPresented: $showInsufficientAlert) {
    Button("Watch Ad (+\(Economy.rewardedAdPayout))") {
        model.ads.showRewarded { model.grantRewardCoins(Economy.rewardedAdPayout) }
    }
    Button("Cancel", role: .cancel) {}
} message: {
    Text("This hint costs \(HintCost.remove). You have \(model.progress.coins).")
}
```

## Implementation Steps
1. Add `Economy.rewardedAdPayout = 50` constant.
2. HomeView: add `@State var adInFlight = false`; insert `freeCoinsButton`.
3. GameView: locate hint-affordability path; add/refactor the alert.
4. Build green.
5. Manual sim: trigger HomeView button → test rewarded ad → +50 persists; trigger hint-alert path → watch → +50 → afford hint.
6. Tests green (no new tests here; Phase 09 covers).
7. Commit: `feat(ads): rewarded UI surfaces (HomeView button + hint alert) [phase-08]`.

## todo list
- [ ] `Economy.rewardedAdPayout = 50`
- [ ] HomeView `freeCoinsButton` + `adInFlight` state
- [ ] GameView hint-insufficient alert with Watch-ad action
- [ ] Build green
- [ ] Manual sim (both surfaces)
- [ ] Tests green
- [ ] Commit

## Success Criteria
- Button visible only when `coins < 90` AND not in `-uitest-reset`.
- Tap → test rewarded → coins +50 → button auto-hides (now ≥90? depends on prior balance; threshold check).
- Hint alert action → +50 → user can retry hint tap.
- No double-fire under rapid taps (`adInFlight` guard).

## Risk Assessment
| Risk | Mitigation |
|---|---|
| Button flickers between show/hide as coins cross threshold | Acceptable (intended UX cue). |
| GameView hint path doesn't currently have an alert | Phase 08 adds it; verify no duplicate alerts if any pre-existing. |
| Reward closure fires after view dismissed (user navigates away mid-ad) | `model.grantRewardCoins` is on AppModel (long-lived); grant still lands. `adInFlight` resets regardless. |
| Test-ad "watched" differs from prod-ad rewarded-event semantics | Phase 09 real-device verification. |

## Security Considerations
None.

## Next steps
→ Phase 09 (Tests + full build verification).
