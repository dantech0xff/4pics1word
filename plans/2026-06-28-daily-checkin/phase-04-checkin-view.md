# Phase 04 — CheckInView

## Context links
- Plan: [plan.md](plan.md)
- Research: [researcher-02 §1–6](../research/researcher-02-checkin-ui.md)
- Prev: [phase-03-appmodel-integration.md](phase-03-appmodel-integration.md)

## Overview
- **Date:** 2026-06-28
- **Description:** New `Views/CheckInView.swift` — `.sheet` at `.medium` detent. 7-day `HStack` tile strip (locked/today/claimed states), prominent Claim button, count-up + `symbolEffect(.bounce)` + `Canvas` confetti, `Feedback.reward()` haptic, full a11y + Reduce Motion fallback.
- **Priority:** P2
- **Impl status:** done
- **Review status:** done

## Key Insights
- **Sheet, not fullScreenCover** (researcher-02 §1). Reward claim is brief + optional; full takeover is overkill (HIG Modality). `.presentationDetents([.medium, .large])` adapts to SE/Pro Max.
- **Reuse `Feedback`** — add `Feedback.reward()` calling cached `notifyGen.notificationOccurred(.success)` after `prepareCelebration()` (researcher-02 §4). Don't reinvent generators.
- **Stock `Canvas` confetti** (~40 lines, no deps) — avoids SwiftUI Confetti third-party lib (researcher-02 §3).
- **Reduce Motion**: skip `.symbolEffect(.bounce)` + confetti → static 0.2s opacity fade + instant count jump. Keep haptics (motion-reduce ≠ haptic-reduce) (researcher-02 §6).
- **Tile states**: claimed (filled + checkmark), today (ring + pulse), locked (gray, opacity 0.4, lock icon). Never color-alone — always pair with SF Symbol (a11y).
- **Day-7 reward (100 coins)** visually distinct: larger coin glyph / accent gradient on that tile (anticipation builder).
- **Count-up source**: `model.lastCheckInReward` (Phase 03). Animate displayed coin value from `oldCoins → oldCoins + lastCheckInReward` over 0.8s.

## Requirements
1. `struct CheckInView: View` taking `model: AppModel` and a `onDismiss: () -> Void`.
2. 7-tile `HStack(spacing: 8)`, each tile a `DayTile` subview (capsule, `@ScaledMetric(44)` height cap).
3. Tile state derived from `model.progress.streakDays` + `model.canCheckInToday`:
   - index `< (streakDays % 7)` (or `== 6 && streakDays % 7 == 0 && streakDays > 0`) → claimed
   - index `== streakDays % 7` and `canCheckInToday` → today
   - else locked
4. Claim button: `.borderedProminent`, `.controlSize(.large)`, label `"Claim \(reward) coins"` (preview today's reward).
5. On tap: call `model.checkIn()`; if non-nil, trigger animation sequence (count-up + confetti + bounce + haptic); disable button; transition today-tile → claimed.
6. If `!canCheckInToday` on appear (manual open after claim): hide Claim button, show "Come back tomorrow" + next-reward preview.
7. `Feedback.reward()` added to `Feedback.swift`.
8. `@Environment(\.accessibilityReduceMotion)` gates confetti + bounce.
9. `@Environment(\.accessibilityReduceTransparency)` → solid background instead of `.ultraThinMaterial`.
10. VoiceOver: per-tile `.accessibilityLabel` + `.accessibilityValue` (state) + `.accessibilityHint`; strip in `.accessibilityElement(children: .contain)`.

## Architecture
```
CheckInView (View)
├─ DayStrip (HStack of 7 DayTile)
│   └─ DayTile(state: .claimed | .today | .locked, day: Int, reward: Int)
├─ ClaimButton (borderedProminent, previews today reward)
├─ ConfettiOverlay (Canvas, gated by reduceMotion)
└─ CountUpCoins (drives displayed value via withAnimation)
```

### Reward curve display
Tile rewards map to `CheckIn.rewards` indices `[0..6]` → `[20,25,30,35,40,50,100]`. Day-7 tile gets accent gradient + larger coin glyph.

### Animation timeline (researcher-02 §3)
1. Tap Claim → `Feedback.prepareCelebration()`.
2. `model.checkIn()` (synchronous).
3. `withAnimation(.spring(duration: 0.4))`: today-tile → claimed (`transition(.scale.combined(with: .opacity))`).
4. `Image(systemName: "coins.fill").symbolEffect(.bounce, options: .repeat(1))`.
5. `withAnimation(.easeOut(duration: 0.8))`: count-up old → new coins.
6. `Feedback.reward()` at count-up midpoint.
7. Confetti `Canvas` burst, `withAnimation(.snappy)` over 1.2s.
8. Reduce Motion path: steps 3–7 collapse to single 0.2s opacity fade + instant count jump.

## Related code files
- `4pics1word/Views/CheckInView.swift` — CREATE
- `4pics1word/Game/Feedback.swift:6` — MODIFY (add `reward()`)
- `4pics1word/Components/CoinCounter.swift:4` — READ (reuse style for count-up)
- `4pics1word/Game/CheckIn.swift:1` — READ (reward curve source)
- `4pics1word/Views/HomeView.swift:21` — READ (presented from here, Phase 05)

## Implementation Steps
1. Add `Feedback.reward()` to `Feedback.swift` (after `celebrationChime`):
   ```swift
   static func reward() {
       guard enabled else { return }
       prepareCelebration()
       notifyGen.notificationOccurred(.success)
   }
   ```
2. Create `4pics1word/Views/CheckInView.swift`.
3. Build `DayTile` (private subview) with 3-state styling.
4. Build `DayStrip` mapping `model.progress.streakDays` → tile states.
5. Build Claim button + on-tap handler calling `model.checkIn()`.
6. Add `@State private var showConfetti = false` + `ConfettiOverlay` Canvas.
7. Add count-up: `@State private var displayedCoins: Int` initialized from `model.progress.coins`, animate on claim.
8. Wire Reduce Motion env var to gate confetti + `symbolEffect`.
9. Add a11y labels per researcher-02 §6.
10. Build + spot-check on iPhone SE simulator (smallest width) and iPhone 16 Pro Max.

## Todo list
- [ ] `Feedback.reward()` added
- [ ] `CheckInView.swift` created with DayTile/DayStrip/Claim/Confetti
- [ ] Reduce Motion fallback verified
- [ ] VoiceOver labels verified (Inspector)
- [ ] Day-7 tile visually distinct

## Success Criteria
- Sheet presents at `.medium` detent; scrolls/extends to `.large` on small devices.
- Tap Claim → coins increment visibly; today-tile flips to claimed; confetti plays.
- Second open same day → Claim button hidden, "Come back tomorrow" shown.
- Reduce Motion on → no bounce, no confetti, instant count.
- VoiceOver reads each tile as "Day N of 7, claimed/today/locked" + reward value.

## Risk Assessment
- **Risk:** 7 tiles overflow iPhone SE width. **Mitigation:** `@ScaledMetric(44)` cap + horizontal `ScrollView` fallback if needed (researcher-02 §2 notes 7×40pt fits SE without scroll).
- **Risk:** Count-up desync from actual `progress.coins` if view re-renders mid-animation. **Mitigation:** drive displayed value from local `@State`, sync to model only on completion.
- **Risk:** `symbolEffect(.bounce)` crashes iOS < 17. **Impact:** none — deployment target is iOS 26.5.

## Security Considerations
None. View is pure presentation; all economy logic in `AppModel.checkIn()` (Phase 03). View cannot grant rewards.

## Next steps
→ Phase 05 (Home auto-popup + toolbar entry).
