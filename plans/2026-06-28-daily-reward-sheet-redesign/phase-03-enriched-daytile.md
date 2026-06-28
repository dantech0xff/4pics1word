# Phase 03 — Enriched DayTile

## Context links
- Plan: [../plan.md](../plan.md)
- Research: [../research/researcher-02-report.md](../research/researcher-02-report.md) (§2, §3, §4)
- Prev phase: [phase-02-two-row-grid-layout.md](./phase-02-two-row-grid-layout.md)
- Next phase: [phase-04-tests-accessibility-pass.md](./phase-04-tests-accessibility-pass.md)

## Overview
- **Date:** 2026-06-28
- **Description:** Replace 44pt capsule DayTile with materially larger square tile carrying day label, coin icon, numeric value, jackpot badge (D7), TODAY pill, claimed ✓, locked 🔒.
- **Priority:** P2
- **Implementation status:** pending
- **Review status:** pending

## Key insights
- Two cell sizes needed: 3-up (bigger) vs 4-up (smaller). Drive via `rowSize` param, not GeometryReader.
- Per researcher-02 §3: 3-up ~110–120pt square, 4-up ~80–90pt square. Use `@ScaledMetric` for Dynamic Type.
- Content stack (top→bottom): "DAY N" caption → coin icon → bold value → state badge.
- Jackpot (D7): same cell size as D4–D6 (Phase 02 decision — keeps grid clean), but golden gradient bg + "JACKPOT" pill (researcher-02 §3 cap = 2×; we stay at 1× w/ emphasis).
- States per researcher-02 §4: claimed (green ✓, scale 0.95, dim), today (pulse + golden glow + TODAY pill top-trailing), locked (padlock + 30% dark scrim, reward still visible).

## Requirements
1. Add `rowSize: DayTileRowSize` enum param (`.three` or `.four`) — drives height + corner radius.
2. Heights: `.three` → 112pt, `.four` → 88pt (both `@ScaledMetric`).
3. Corner radius: 18pt (`RoundedRectangle` replaces `Capsule`).
4. Content VStack: caption ("DAY N") → coin icon (`circle.fill` yellow, or `bitcoinsign.circle.fill`) → value (bold) → state badge.
5. **Jackpot (D7)**: golden linear gradient bg (yellow→orange), "JACKPOT" pill overlay top-leading, larger value font.
6. **Today**: pulse animation (keep existing `pulse` bool), golden glow shadow, "TODAY" pill top-trailing.
7. **Claimed**: green checkmark circle overlay center, scale 0.95, foreground desaturated.
8. **Locked**: padlock overlay, 30% black scrim over content (reward still readable).
9. Preserve existing `accessibilityLabel`/`Value`/`Hint` (L197-199) — augment w/ jackpot hint.
10. Keep `MainActor` default isolation; no `nonisolated` needed.

## Architecture
Extend `DayTile` struct. New small enum. No new views (badges are overlays, not separate types — DRY).

```swift
private enum DayTileRowSize { case three, four }

private struct DayTile: View {
    let day: Int
    let reward: Int
    let state: DayTileState
    let isJackpot: Bool
    let pulse: Bool
    let rowSize: DayTileRowSize

    @ScaledMetric private var threeHeight: CGFloat = 112
    @ScaledMetric private var fourHeight: CGFloat = 88
    @ScaledMetric private var corner: CGFloat = 18

    private var height: CGFloat { rowSize == .three ? threeHeight : fourHeight }

    var body: some View {
        ZStack {                     // badge overlays sit on top
            contentColumn
                .frame(height: height)
                .frame(maxWidth: .infinity)
                .background(tileBackground)
                .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
                .overlay(stateOverlay)        // today border / claimed check / locked lock
                .overlay(jackpotBadge)        // conditional
                .overlay(todayPill)           // conditional
                .opacity(stateOpacity)
                .scaleEffect(state == .claimed ? 0.95 : (state == .today && pulse ? 1.05 : 1))
                .shadow(state == .today ? glow : .clear)
        }
        .accessibilityLabel("Day \(day) of 7")
        .accessibilityValue(valueLabel)
        .accessibilityHint(a11yHint)
    }
}
```

### Badge pseudo-SwiftUI
```swift
// Jackpot pill (D7 only), top-leading
if isJackpot {
    Text("JACKPOT").font(.caption2.weight(.bold)).padding(.horizontal,6).padding(.vertical,2)
        .background(Capsule().fill(.orange))
        .frame(maxWidth:.infinity, maxHeight:.infinity, alignment:.topLeading)
        .padding(6)
}
// TODAY pill (today only), top-trailing
if state == .today {
    Text("TODAY").font(.caption2.weight(.bold))...
        .frame(maxWidth:.infinity, maxHeight:.infinity, alignment:.topTrailing)
}
// Claimed check (centered)
if state == .claimed { Image(systemName:"checkmark.circle.fill").foregroundStyle(.green) }
// Locked lock (top-trailing, no pill conflict — locked != today)
if state == .locked { Image(systemName:"lock.fill") }
```

### Backgrounds
```swift
// Jackpot
LinearGradient(colors:[.yellow,.orange], startPoint:.top, endPoint:.bottom)
// Today
Color.accentColor.opacity(0.2)
// Claimed
Color.secondary.opacity(0.15)
// Locked
Color.secondary.opacity(0.1) + Color.black.opacity(0.3) scrim overlay
```

## Related code files
- `4pics1word/Views/CheckInView.swift:171` — `DayTileState` enum (no change; verify states match).
- `4pics1word/Views/CheckInView.swift:173-248` — `DayTile` struct (full rewrite).
- `4pics1word/Views/CheckInView.swift:82-95` — `dayStrip` (Phase 02): pass `rowSize: .three` for indices 0..3, `.four` for 3..<7.
- `4pics1word/Game/CheckIn.swift:4` — rewards [20,25,30,35,40,50,100]; D7=100 jackpot.
- `4pics1word/Game/Feedback.swift` — no change (reward burst already fires).

## Implementation steps
1. Add `DayTileRowSize` enum.
2. Rewrite `DayTile` per sketch above: parametric height, `RoundedRectangle`, content column, overlay stack.
3. Update `dayStrip` (Phase 02) to pass `rowSize` based on row index.
4. Tune jackpot pill / today pill positioning via `.frame(maxWidth:.infinity, alignment:)` (no GeometryReader).
5. Verify reduce-motion path: pulse disabled but TODAY pill still renders (static).
6. Verify reduce-transparency: golden gradient still OK (it's opaque, not material — fine).
7. Visual sweep all 7 day states across claim states:
   - Fresh (D1 today, D2–7 locked, D7 jackpot-locked).
   - Mid-streak (D4 today, D1–3 claimed, D5–7 locked).
   - Day 7 claim moment (D7 jackpot-today).

## Todo
- [ ] Add `DayTileRowSize` enum
- [ ] Rewrite `DayTile` with parametric sizing + `RoundedRectangle`
- [ ] Implement content column (caption/icon/value)
- [ ] Implement 4 state overlays (today/claimed/locked/jackpot)
- [ ] Implement TODAY pill + JACKPOT pill
- [ ] Wire `rowSize` from `dayStrip`
- [ ] Verify reduce-motion + reduce-transparency paths
- [ ] Visual state sweep (fresh / mid-streak / D7-claim)

## Success criteria
- 3-up tiles visibly ~110pt, 4-up tiles ~85pt.
- Day 7 unambiguously reads as jackpot (golden bg + JACKPOT pill).
- Today's tile pulses + has TODAY pill + golden glow.
- Claimed tiles show green ✓, slightly smaller, desaturated.
- Locked tiles show reward + padlock + scrim, but reward still readable.
- Dynamic Type XL doesn't break layout (caps lock tiles to container width).
- VoiceOver reads each tile as "Day N of 7, <state>, Reward: N coins" (+ "Jackpot day" for D7).

## Risk assessment
| Risk | Likelihood | Mitigation |
|---|---|---|
| Tile overflow at AX5 XL | Med | Cap `@ScaledMetric` via `.dynamicTypeSize(...DynamicTypeSize.accessibility3)` |
| Today glow too subtle / too loud | Med | Tunable shadow radius; verify both light/dark mode |
| Jackpot gradient clashes w/ accentColor | Low | Use system yellow→orange, independent of accent |
| Reduce-transparency hides gradients | Low | Gradients are opaque (not material); unaffected |
| 4-up + 18pt radius looks cramped | Low | If bad, drop 4-up radius to 14pt (still >8pt floor) |

## Security considerations
None. Pure presentation.

## Next steps
→ Phase 04 (tests + a11y pass). Validate full claim flow, update UI test contract, run xcodebuild.

## Unresolved questions
1. Coin icon: SF Symbol `circle.fill` (current) vs `bitcoinsign.circle.fill` (more semantic)? → Prefer `bitcoinsign.circle.fill` if available on iOS 26; fallback `circle.fill`.
2. Jackpot pill placement top-leading vs top-trailing when D7 is locked (padlock also top-trailing)? → Lock goes top-trailing, JACKPOT top-leading (no conflict).
3. Should claimed checkmark replace the coin icon or overlay center? → Overlay center, keep coin icon below (researcher-02 §4 implies layered closure signal).
