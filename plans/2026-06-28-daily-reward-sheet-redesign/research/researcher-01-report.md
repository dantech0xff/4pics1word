# Daily Reward Sheet — Dismiss-Control Research

**Scope:** Force-claim gate on `.sheet` with `[.medium, .large]` detents. iOS 26 / SwiftUI.
**Verdict:** Use `.interactiveDismissDisabled(!canDismiss)` + always-present Close button that morphs between "disabled-hint" and "active" states + warning haptic on dismiss attempt. Never trap VoiceOver users.

---

## 1. `interactiveDismissDisabled(_:)` Behavior

**API:** `func interactiveDismissDisabled(_ isDisabled: Bool = true) -> some View` — iOS 15+ ([Apple Docs](https://developer.apple.com/documentation/swiftui/view/interactivedismissdisabled(_:))). Applied to **sheet content**, not the presentation call.

| Dismiss vector | Blocked? |
|---|---|
| Swipe-down (interactive) | ✅ Yes |
| Pull-past-shortest-detent | ✅ Yes |
| Tap outside (popover/fullScreen) | N/A (sheets don't dismiss on outside tap) |
| Programmatic `@Environment(\.dismiss)` | ❌ **No — still works** |
| Parent state change that flips `.isPresented` | ❌ No |
| System gesture (back swipe from nav) inside sheet | ❌ No |

**iOS 26 caveats:** No API change. Multiwindow/Stage Manager on iPad: the disabled state is respected per-scene. On iPadOS in compact width, sheets may present as form-sheet — verify on device. iOS 16/17/26 behavior is consistent for this modifier.

**Conditional pattern:** Take a Bool, not a Binding — recompute from your state:

```swift
struct RewardSheet: View {
    @Environment(\.dismiss) private var dismiss
    let rewardClaimed: Bool             // from parent / VM
    var body: some View {
        ClaimContent()
            .interactiveDismissDisabled(!rewardClaimed)
    }
}
```

Parent flips the bool via `@State` + `.sheet(isPresented:)` or `@Environment(\.dismiss)` after claim.

**Key rule:** Because programmatic dismiss is *not* blocked, always expose your own Close button — that's the escape hatch.

---

## 2. Close Button When Sheet Can't Dismiss

**HIG ([Sheets](https://developer.apple.com/design/human-interface-guidelines/sheets)) implies:** don't strand users; always provide an explicit, obvious exit. Three idiomatic patterns observed in production:

### Pattern A — Visible-but-disabled + hint (recommended; matches Apple Pay / App Store)
Keeps affordance discoverable, communicates gate, preserves muscle memory.
```swift
Button { attemptClose() } label: { Image(systemName: "xmark") }
    .disabled(!canClaim)
    .opacity(canClaim ? 1 : 0.4)
    .accessibilityHint(canClaim ? "Closes the sheet." : "Disabled. Claim your reward first.")
```

### Pattern B — Morph into primary CTA (gacha / daily-reward games — "Coin Master", "Marvel Snap")
Hide X entirely; the only button is **Claim**. Post-claim, swap to Close.
```swift
HStack { Spacer(); headerControl }
// where headerControl = canClaim ? closeButton : EmptyView()
// and bottomBar always has the Claim button (the only exit action)
```
Strongest forcing function; weakest discoverability — add hint.

### Pattern C — Persistent X, shake/warn on tap (Apple "Sign in" / iCloud password flows)
Tap X when disabled → warning haptic + toast/inline explanation. Lets user *investigate* the gate.

**Recommendation for daily reward:** **Pattern A** if you want post-claim dismissal to stay easy; **Pattern B** if conversion is the goal. Don't fully hide without leaving the bottom CTA.

---

## 3. Detents × `interactiveDismissDisabled`

**API:** `.presentationDetents([.medium, .large])` ([Apple Docs](https://developer.apple.com/documentation/swiftui/view/presentationdetents(_:))) + `.presentationDragIndicator(.visible)`.

- Disabled dismiss **does NOT lock detent.** User can still drag between `.medium` ↔ `.large`.
- Only the *overshoot past shortest detent* is blocked. Sheet snaps back to `.medium` on release.
- Drag indicator stays visible — expected.
- No animation/geometry glitch introduced by combining the two modifiers.

```swift
.sheet(isPresented: $show) {
    RewardSheet(rewardClaimed: claimed)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(!claimed)
}
```

Edge: if your shortest detent is `.large`-only, dismissing already requires intent — disabling has near-zero visual cost. With `.medium` as shortest, you'll see the snap-back clearly.

---

## 4. Accessibility — Don't Trap VoiceOver Users

**Critical:** A non-dismissible sheet is a UX trap if the only escape is a hidden gesture.

Required:
- **Close button must remain in the accessibility tree** (don't use `.opacity(0)` + `.allowsHitTesting(false)` together — VoiceOver skips invisible elements).
- Set `.accessibilityHint` declaring state.
- Optionally announce state change on appearance with `@Environment(\.accessibilityVoiceOverEnabled)` + `UIAccessibility.post(notification:.announcement, ...)` or SwiftUI `.accessibilityNotification(.announcement(...))`.

```swift
@Environment(\.accessibilityVoiceOverEnabled) private var voiceOver

Button(action: attemptClose) {
    Image(systemName: "xmark").padding(8)
}
.accessibilityLabel("Close")
.accessibilityHint(canClaim
    ? "Closes the reward sheet."
    : "Disabled until you claim today's reward. Double-tap the Claim button to continue.")
.opacity(canClaim ? 1 : 0.5)
```

**Conventions:** VoiceOver hint reads *purpose*, label reads *name*. Keep hint ≤ 1 sentence. HIG [Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility) — "Don't trap people".

Avoid `.accessibilityHidden(true)` on the close button.

---

## 5. Haptics When Gate Engaged

**Modern API (iOS 17+, default on iOS 26):** `.sensoryFeedback(_, trigger:)` ([Apple Docs](https://developer.apple.com/documentation/swiftui/view/sensoryfeedback(_:trigger:))). Declarative, no generators to manage.

```swift
// Warning bump when user attempts to dismiss without claiming
.sensoryFeedback(.warning, trigger: dismissAttemptCount)
// where dismissAttemptCount increments on each blocked X-tap or drag-past-detent
```

For **drag attempts** (not just button taps) you need an observable signal — there's no public callback for "blocked interactive dismiss". Workarounds:
- Detect via `UIScreen.onChange` of a custom `DismissAttemptMonitor` (fragile).
- Simpler: only fire haptic from your **Close button's** `attemptClose()` path. Drag-past-blocked is silent (system already snaps back — felt as drag resistance).

```swift
func attemptClose() {
    guard canClaim else {
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.8)
        // or use .warning sensoryFeedback above
        showClaimHintToast = true
        dismissAttemptCount += 1
        return
    }
    dismiss()
}
```

**HIG [Playing Haptics](https://developer.apple.com/design/human-interface-guidelines/playing-haptics):** use `.warning` sparingly — reserve for true "you can't proceed" moments. `.rigid` impact for a deliberate "no" feel. Don't stack haptics within 100 ms.

`UIImpactFeedbackGenerator`/`UINotificationFeedbackGenerator` still work on iOS 26; prefer `.sensoryFeedback` in pure SwiftUI.

---

## TL;DR Recommendation

```swift
DailyRewardView(...)
    .presentationDetents([.medium, .large])
    .presentationDragIndicator(.visible)
    .interactiveDismissDisabled(!claimed)
    .sensoryFeedback(.warning, trigger: attempts)
```
+ Always-on `X` button (Pattern A) with `.disabled(!claimed)`, dimmed `.opacity(0.5)`, `.accessibilityHint` describing the gate.
+ Haptic on tap-when-disabled only; drag resistance handles itself.

---

## Sources

- [interactiveDismissDisabled(_:) — Apple Docs](https://developer.apple.com/documentation/swiftui/view/interactivedismissdisabled(_:))
- [presentationDetents(_:) — Apple Docs](https://developer.apple.com/documentation/swiftui/view/presentationdetents(_:))
- [sensoryFeedback(_:trigger:) — Apple Docs](https://developer.apple.com/documentation/swiftui/view/sensoryfeedback(_:trigger:))
- [accessibilityHint(_:) — Apple Docs](https://developer.apple.com/documentation/swiftui/view/accessibilityhint(_:))
- [HIG — Sheets](https://developer.apple.com/design/human-interface-guidelines/sheets)
- [HIG — Playing Haptics](https://developer.apple.com/design/human-interface-guidelines/playing-haptics)
- [HIG — Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)
- WWDC22 — *Use SwiftUI with UIKit* (session 10072) — dismiss coordination
- WWDC23 — *Discover Observation in SwiftUI* (session 10149) — reactive `canDismiss` flags

## Unresolved / Open Questions

1. Is there an iPad form-sheet presentation difference for this sheet on iPadOS 26 in regular width? Need device test (AGENTS.md lists iPhone+iPad target).
2. Should blocked-drag also fire haptic? No public callback exists; would need a `UIViewRepresentable` overlay observing `UIPanGestureRecognizer` velocity. Worth the complexity? (Probably **no** — YAGNI.)
3. Post-claim auto-dismiss vs let user dismiss manually? Product decision — recommend letting user dismiss (feels less aggressive) but auto-flip Close to enabled.
4. Persistence semantics for `claimed`: does the daily reward VM mark claimed synchronously on tap, or after a network/StoreKit transaction? Affects when `interactiveDismissDisabled` flips — must gate on local optimistic state to avoid user getting stuck mid-network.
