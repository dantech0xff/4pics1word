# Phase 03 — Cell State Polish

## Context links
- Plan: [../plan.md](../plan.md)
- Research: [../research/researcher-02-report.md](../research/researcher-02-report.md) (§2, §3, §4, §5, §7, §9)
- Prev: [phase-02-uniform-grid-layout.md](./phase-02-uniform-grid-layout.md)
- Source: `4pics1word/Views/CheckInView.swift:241-386` (contentColumn, tileBackground, stateOverlay, badges, a11y)
- Next: [phase-04-claim-animation.md](./phase-04-claim-animation.md)

## Overview
- **Date:** 2026-06-29
- **Description:** Soften locked state (desaturate + material chip), jackpot `gift.fill` icon, today shimmer, Dynamic Type cap `.accessibility2`, refined VoiceOver labels w/ "claim in N days".
- **Priority:** P2
- **Implementation status:** pending
- **Review status:** pending

## Key insights
- **Locked harshness:** current `Color.black.opacity(0.3)` scrim reads "disabled/broken" not "coming soon" (researcher-02 §4). Replace w/ desaturation (~40%) + lightness +5% HSL shift; keep reward legible (WCAG AA 4.5:1).
- **Lock chip:** `lock.fill` in `.ultraThinMaterial` circle (not black) — iOS 26 glass direction.
- **Iconography (researcher-02 §3):** keep coin icon days 1–6 (economy alignment); D7 jackpot → `gift.fill`. Avoid `star.fill`/`wand.and.stars`/`seal.fill` (semantic conflation).
- **Jackpot:** same cell footprint (Phase 02 decision); differentiate via golden gradient + `gift.fill` + JACKPOT pill. No scale/size break (researcher-02 §5).
- **Shimmer (researcher-02 §7):** 2.5s diagonal gradient mask sweep on today cell — reduce-motion-gated. Static fallback: accent ring only.
- **Dynamic Type cap:** researcher-02 §9 — `.accessibility2` (current `.accessibility3` risks overflow in 4-up).
- **VoiceOver (researcher-02 §9):** state-aware labels w/ "claim in N days" for locked; `.isButton` only on today cell; others `.isStaticText`.
- **Colour-blind:** never rely on green-check vs red-lock alone — icon shape carries meaning (✓).

## Requirements
### Functional
- F1: Locked cells desaturated (no black scrim); `.ultraThinMaterial` lock chip top-trailing.
- F2: D7 jackpot uses `gift.fill` icon + golden gradient bg + JACKPOT pill; days 1–6 keep coin icon.
- F3: Today cell shimmers (diagonal sweep, 2.5s loop) when `!reduceMotion`; static ring when reduce-motion.
- F4: Dynamic Type capped `.accessibility2`.
- F5: VoiceOver labels: claimed `"Day N, M coins, claimed"`; today `"Day N, M coins, available to claim"` (+jackpot); locked `"Day N, M coins, locked, claim in X days"`.
- F6: Today cell exposes `.isButton` + `accessibilityAction`; others `.isStaticText` (non-interactive).

### Non-functional
- NF1: Reduce-transparency: `.ultraThinMaterial` → solid secondary fill fallback.
- NF2: Colour-blind safe: state conveyed by icon shape (✓/🔒/gift) not hue alone.
- NF3: No new types — overlays + modifiers only (DRY).

## Architecture
Extend `DayTile` (Phase 02 uniform version). Add shimmer View modifier. Keep overlay-stack pattern.

### Locked softening
```swift
// stateOverlay — BEFORE (locked)
RoundedRectangle(...).fill(Color.black.opacity(0.3))

// AFTER — no scrim; desaturate content instead
contentColumn
    .saturation(state == .locked ? 0.4 : 1.0)        // desaturate
    .brightness(state == .locked ? 0.05 : 0)         // lift lightness
// lock chip: .ultraThinMaterial circle (fallback solid via reduceTransparency)
if state == .locked {
    Image(systemName: "lock.fill")
        .padding(4)
        .background(Circle().fill(.ultraThinMaterial))   // not black
}
```

### Jackpot icon
```swift
private var iconName: String {
    if isJackpot { return "gift.fill" }       // D7
    return "bitcoinsign.circle.fill"          // D1–6
}
// contentColumn: Image(systemName: iconName).foregroundStyle(isJackpot ? .white : .yellow)
```

### Shimmer (today only, reduce-motion-gated)
```swift
// New private struct ShimmerModifier: ViewModifier — diagonal gradient mask, 2.5s loop
// Apply: .modifier(state == .today && !reduceMotion ? ShimmerModifier() : EmptyShimmer())
// Static fallback (reduceMotion): accent ring only (existing strokeBorder)
```

### Dynamic Type + a11y
```swift
.dynamicTypeSize(...DynamicTypeSize.accessibility2)   // was .accessibility3
// labels:
switch state {
case .claimed:  "Day \(day), \(reward) coins, claimed"
case .today:    "Day \(day), \(reward) coins, available to claim" + (isJackpot ? ", jackpot" : "")
case .locked:   "Day \(day), \(reward) coins, locked, claim in \(day - claimedCount) days"
}
// today only: .accessibilityAddTraits(.isButton); others .accessibilityAddTraits(.isStaticText)
```

## Related code files
- **Modify:** `4pics1word/Views/CheckInView.swift:241-257` — `contentColumn`: `iconName` computed; `saturation`/`brightness` on locked.
- **Modify:** `4pics1word/Views/CheckInView.swift:270-288` — `tileBackground`: keep jackpot gradient; locked bg → remove reliance on scrim.
- **Modify:** `4pics1word/Views/CheckInView.swift:292-321` — `stateOverlay`: delete `Color.black.opacity(0.3)`; lock chip → `.ultraThinMaterial` circle.
- **Modify:** `4pics1word/Views/CheckInView.swift:232` — `.dynamicTypeSize(...)` cap → `.accessibility2`.
- **Modify:** `4pics1word/Views/CheckInView.swift:233-236` — a11y labels w/ "claim in N days"; traits.
- **Create:** new private `ShimmerModifier` (or inline `mask` animation) in CheckInView.swift.
- **No change:** `CheckIn.swift`, `AppModel.swift`, `Feedback.swift`, `AppRootView.swift`.

## Implementation steps
1. Add `iconName` computed in `DayTile`; wire `gift.fill` for jackpot, coin for others. Update `contentColumn` Image.
2. Remove `Color.black.opacity(0.3)` scrim from `stateOverlay` locked case.
3. Add `.saturation`/`.brightness` modifiers to content column (locked only). Verify reward value still WCAG AA legible.
4. Replace lock chip bg `Circle().fill(Color.black.opacity(0.5))` → `Circle().fill(.ultraThinMaterial)`. Gate solid fallback via `reduceTransparency`.
5. Change `.dynamicTypeSize(...accessibility3)` → `...accessibility2` (CheckInView.swift:232).
6. Rewrite a11y label/value/hint per F5. Add `.accessibilityAddTraits` — `.isButton` today, `.isStaticText` others.
7. Add `ShimmerModifier` (diagonal gradient mask, 2.5s `TimelineView`-driven or repeating animation). Apply to today cell, `reduceMotion`-gated.
8. Build iPhone 16 sim.
9. Visual sweep: locked desaturation (light/dark mode), jackpot gift icon + gradient, today shimmer (motion on/off), AX2 Dynamic Type fit.
10. Sim Daltonism check: claimed (✓) vs locked (🔒) distinguishable w/o colour.

## Todo
- [ ] `iconName`: `gift.fill` jackpot, coin days 1–6
- [ ] Remove black scrim (locked)
- [ ] Add `.saturation(0.4)`/`.brightness(0.05)` locked
- [ ] Lock chip → `.ultraThinMaterial` (+ reduce-transparency solid fallback)
- [ ] Dynamic Type cap → `.accessibility2`
- [ ] VoiceOver labels w/ "claim in N days" + traits
- [ ] Shimmer modifier (today, reduce-motion-gated)
- [ ] Build green
- [ ] Visual sweep (locked desat / jackpot / shimmer / AX2)
- [ ] Sim Daltonism colour-blind check

## Success criteria
- Locked cells visibly desaturated, no black overlay; lock chip glassy not dark.
- D7 shows `gift.fill` + golden gradient; reads as jackpot at a glance.
- Today cell shimmers when motion enabled; static ring when reduce-motion.
- Dynamic Type `.accessibility2` — no overflow in 4-up row.
- VoiceOver reads full state incl "claim in N days" for locked.
- Claimed vs locked distinguishable in Sim Daltonism (icon-based, not hue-based).
- reduce-transparency: materials swap to solid fills cleanly.

## Risk assessment
| Risk | Likelihood | Mitigation |
|---|---|---|
| Desaturation drops reward contrast below AA | Med | Verify contrast ratio; tune saturation 0.4→0.5 if needed |
| `.ultraThinMaterial` invisible on bright bg | Low | Add subtle stroke ring around chip |
| Shimmer loop CPU/GPU cost | Low | `TimelineView` w/ 2.5s cadence; only 1 cell active; reduce-motion off-path |
| AX2 still overflows 4-up | Low | Reduce `cellHeight` base or value font; verified Phase 02 |
| `gift.fill` rendering at small size | Low | SF Symbol optimised for small sizes; verify on SE |

## Security considerations
None. Presentation + a11y.

## Next steps
→ Phase 04 (claim animation). Spring tap + coin fly-to-wallet via matchedGeometryEffect to header counter.

## Unresolved questions
1. Shimmer technique — `TimelineView` (preferred, declarative) vs `mask`+`offset` repeating animation (imperative)? Default TimelineView (iOS 26 clean).
2. "claim in X days" wording — `day - claimedCount` correct only if days ordered; verify against `CheckIn.nextStreakDay` wrap (week rollover). If week rolls, "claim in N days" may mislead — confirm logic w/ streak reset.
3. Should jackpot `gift.fill` also apply to claimed D7 (or revert to coin)? Default: keep gift.fill claimed (visual continuity).
4. Saturation 0.4 — empirical tune; may need 0.5–0.6 for AA contrast on yellow coin.
