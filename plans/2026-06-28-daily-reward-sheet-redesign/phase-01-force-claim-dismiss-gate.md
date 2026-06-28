# Phase 01 — Force-claim dismiss gate

## Context links
- Plan: [../plan.md](../plan.md)
- Research: [../research/researcher-01-report.md](../research/researcher-01-report.md) (§1–§5)
- Next phase: [phase-02-two-row-grid-layout.md](./phase-02-two-row-grid-layout.md)

## Overview
- **Date:** 2026-06-28
- **Description:** Make sheet non-dismissible (swipe + X) while reward is claimable. Free after claim or if pre-claimed.
- **Priority:** P2
- **Implementation status:** pending
- **Review status:** pending

## Key insights
- `model.canCheckInToday` is the single source of truth — already observable, flips synchronously on `checkIn()`. No new state needed (DRY).
- `.interactiveDismissDisabled(_:)` blocks swipe-down + pull-past-detent but **not** programmatic dismiss (`@Environment(\.dismiss)`) — so we still need an always-rendered Close button (Pattern A).
- Per researcher-01 §4: never hide Close from VoiceOver. Always in a11y tree, with hint describing gate.
- Haptic only on Close-tap-when-disabled; drag-block is silent (system provides drag resistance).

## Requirements
1. `canDismiss: Bool` computed property on `CheckInView` = `!model.canCheckInToday`.
2. `.interactiveDismissDisabled(!canDismiss)` on `CheckInView` in `AppRootView`.
3. Close button stays visible always; `.disabled(!canDismiss)`; `.opacity(canDismiss ? 1 : 0.4)`.
4. `.accessibilityHint` morphs: enabled → "Closes the reward sheet." / disabled → "Disabled until you claim today's reward. Double-tap the Claim button to continue."
5. Tap-on-disabled Close fires `Feedback.warning()` (new). No-op otherwise.
6. `.presentationDragIndicator(.visible)` added (currently absent — researcher-01 §3).

## Architecture
No new types. Add computed property + warning haptic. Stateless gate derived from existing observable.

```swift
// CheckInView.swift
private var canDismiss: Bool { !model.canCheckInToday }

private func attemptClose() {
    guard canDismiss else {
        Feedback.warning()
        return
    }
    onDismiss()
}

// header Close button
Button(action: attemptClose) { /* xmark */ }
    .disabled(!canDismiss)
    .opacity(canDismiss ? 1 : 0.4)
    .accessibilityLabel("Close")
    .accessibilityHint(canDismiss
        ? "Closes the reward sheet."
        : "Disabled until you claim today's reward. Double-tap the Claim button to continue.")
```

```swift
// AppRootView.swift lines 23–26
.sheet(isPresented: $showCheckinSheet) {
    CheckInView(model: model) { showCheckinSheet = false }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(!model.canCheckInToday)
}
```

```swift
// Feedback.swift — append
static func warning() {
    guard enabled else { return }
    notifyGen.notificationOccurred(.warning)
}
```

## Related code files
- `4pics1word/Views/CheckInView.swift:57-80` — header (Close button).
- `4pics1word/Views/CheckInView.swift:131-151` — `claimTapped` (no change; flips `canCheckInToday` → `canDismiss` true).
- `4pics1word/Views/AppRootView.swift:23-26` — sheet presentation; add 2 modifiers.
- `4pics1word/Game/Feedback.swift:6-57` — add `warning()` near `wrong()` (L19-22 pattern).
- `4pics1word/Game/AppModel.swift` — read-only consumer of `canCheckInToday` (no change).

## Implementation steps
1. Add `Feedback.warning()` to `Feedback.swift` (uses existing cached `notifyGen`).
2. In `CheckInView.swift`:
   - Add `private var canDismiss: Bool { !model.canCheckInToday }`.
   - Add `private func attemptClose()` with guard + warning.
   - Update Close button (L71-77): wire to `attemptClose`, add `.disabled` / `.opacity` / `.accessibilityHint`.
3. In `AppRootView.swift` sheet block (L23-26): add `.presentationDragIndicator(.visible)` + `.interactiveDismissDisabled(!model.canCheckInToday)`.
4. In `CheckInUITests.swift` `testToolbarButtonReopensSheetAfterDismiss` (L58-71): tap `Claim 20 coins` before `Close` (Close is now disabled pre-claim).
5. Build + run all tests.

## Todo
- [ ] Add `Feedback.warning()` to `Feedback.swift`
- [ ] Add `canDismiss` + `attemptClose()` to `CheckInView.swift`
- [ ] Update Close button styling + a11y hint in `CheckInView.swift` header
- [ ] Add `.presentationDragIndicator(.visible)` + `.interactiveDismissDisabled` in `AppRootView.swift`
- [ ] Update `testToolbarButtonReopensSheetAfterDismiss` to claim-first
- [ ] `xcodebuild build` green
- [ ] `xcodebuild test` green

## Success criteria
- Swipe-down on pre-claim sheet snaps back to `.medium` (no dismiss).
- Pre-claim X tap: no dismiss + warning haptic + Close stays in VoiceOver tree.
- Post-claim: swipe + X both dismiss.
- Pre-claimed-on-open sheet (relaunch after claim): swipe + X both dismiss immediately.

## Risk assessment
| Risk | Likelihood | Mitigation |
|---|---|---|
| `interactiveDismissDisabled` ignored on iPad form-sheet | Low (iOS 26 unified) | Defer to device test; researcher-01 §1 says consistent |
| Close button loses VoiceOver focus when state flips | Low | Hint is dynamic; no `accessibilityHidden` |
| Test contract breakage cascades | Med | Phase 04 covers full audit |
| Double haptic if user spams X | Low | `disabled` blocks repeat taps; warning fires once per enabled cycle |

## Security considerations
None. No auth, no network, no persistence change. Gate is pure UI derived from already-trusted `model.canCheckInToday`.

## Next steps
→ Phase 02 (two-row grid layout). Independent of gate but shares `CheckInView.body` — merge after 01 ships.
