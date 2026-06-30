# Phase 01 — 3-3-1 Grid + Full-Width Jackpot Tile

## Context links
- Parent plan: `../plan.md`
- Dependency: none (first phase).
- Research: `../research/researcher-01-report.md` (§1 grid, §3 jackpot UI).
- Scout: `../scout/scout-01-report.md` (regions L99–112, L136–148, L398–412).
- Source: `4pics1word/Views/CheckInView.swift`.

## Overview
- Date: 2026-06-30
- Description: Rewrite `dayStrip` to 3+3+jackpot; give unclaimed Day-7 a full-width horizontal layout w/ inline JACKPOT pill; vertical fallback for locked/claimed/AX.
- Priority: P2
- Implementation status: pending
- Review status: pending

## Key Insights (researcher-01)
- Current 4+3 (L103–109) → row-2 tiles already wider than row-1 (each `DayTile` `.frame(maxWidth:.infinity)` L279; HStack shares width among N children). 3+3 makes both rows equal-width. Fixes imbalance.
- `LazyVGrid` 3-col puts item-7 in col-0 row-3 (1/3 wide, left-aligned) → no win. `Grid`/`GridRow` has no colspan API → boilerplate. Manual HStack is idiomatic iOS 26.
- L109 `.frame(maxWidth:.infinity)` on 2nd HStack is redundant inside VStack — drop.
- Jackpot full-width earns horizontal layout: `gift.fill` + `(DAY 7 / 100)` + `Spacer` + `JACKPOT` capsule. Delete `jackpotBadge` overlay (L398–412) — pill moves inline.
- Locked/claimed jackpot keeps vertical `contentColumn` (visual consistency w/ days 1–6).
- `todayCellFrameReader` (L469–479) MUST stay attached to jackpot tile when day-7 is today — coin-fly origin depends on it.

## Requirements
1. `dayStrip` renders 3 tiles + 3 tiles + 1 full-width jackpot.
2. Row-1 and row-2 tiles equal width.
3. Unclaimed Day-7: horizontal HStack layout, inline JACKPOT pill (right-anchored).
4. Locked/claimed Day-7: vertical `contentColumn` (unchanged).
5. AX-size (`dynamicTypeSize.isAccessibilitySize`): jackpot flips vertical to avoid truncation.
6. `todayCellFrameReader` still attached when day-7 == today.
7. No cell-content change for days 1–6 (layout-only).

## Architecture

### `dayStrip` rewrite (L99–112)
```swift
private var dayStrip: some View {
    VStack(spacing: 12) {
        progressDots
        VStack(spacing: 8) {
            HStack(spacing: 8) { ForEach(0..<3, id: \.self) { dayTile(for: $0) } }
            HStack(spacing: 8) { ForEach(3..<6, id: \.self) { dayTile(for: $0) } }
            dayTile(for: 6)                                   // jackpot, full width
        }
    }
}
```
(Drops L109 redundant `.frame(maxWidth:.infinity)`.)

### Jackpot horizontal variant — branch in `DayTile.body` (L275)
Pre-existing `contentColumn` stays as vertical fallback. Add sibling `jackpotRow` (horizontal); pick via `shouldUseJackpotRow`:
```swift
private var shouldUseJackpotRow: Bool {
    isJackpot && state != .claimed && !dynamicTypeSize.isAccessibilitySize
}
// body ZStack content:
if shouldUseJackpotRow { jackpotRow } else { contentColumn }
```
`jackpotRow` (new private var):
```swift
HStack(spacing: 10) {
    Image(systemName: "gift.fill")
        .font(.title)
        .foregroundStyle(.white)
    VStack(alignment: .leading, spacing: 2) {
        Text("DAY \(day)").font(.caption2.weight(.semibold)).foregroundStyle(.white)
        Text("\(reward)").font(.title2.weight(.bold)).monospacedDigit().foregroundStyle(.white)
    }
    Spacer()
    Text("JACKPOT")
        .font(.system(size: 9, weight: .heavy))
        .foregroundStyle(.white)
        .padding(.horizontal, 6).padding(.vertical, 2)
        .background(Capsule().fill(Color.orange))
}
.padding(.horizontal, 12)
.frame(height: cellHeight).frame(maxWidth: .infinity)
```
Keep all existing overlays EXCEPT `jackpotBadge` (deleted — pill now inline). Keep `tileBackground` (golden gradient L336 still paints), `stateOverlay` (today ring only), `todayPill`, `shimmerOverlay`, `todayCellFrameReader`, a11y (L297–300).

### `jackpotBadge` (L398–412) — delete entirely.

## Related code files
- `4pics1word/Views/CheckInView.swift` — L99–112 (`dayStrip`), L275–301 (`DayTile.body`), L305–321 (`contentColumn` keep), L398–412 (`jackpotBadge` delete), L469–479 (`todayCellFrameReader` keep attached).
- Read-only ref: `4pics1word/Game/CheckIn.swift` L4 (rewards idx 6 = jackpot).

## Implementation Steps
1. L103–109: rewrite `dayStrip` inner VStack to 3+3+jackpot (see Architecture). Drop L109 redundant frame.
2. L275–293 `DayTile.body`: wrap `contentColumn` in `if shouldUseJackpotRow { jackpotRow } else { contentColumn }`. Both branches keep `.frame(height: cellHeight).frame(maxWidth:.infinity)` + identical overlay chain (background/clip/overlays/opacity/scale/shadow/frameReader).
3. Add `private var shouldUseJackpotRow: Bool` computed prop.
4. Add `private var jackpotRow: some View` per Architecture snippet.
5. Delete `jackpotBadge` view (L398–412) AND its `.overlay(jackpotBadge)` reference in body (L285).
6. Confirm `todayCellFrameReader` (L292) still in overlay chain for both branches (coin-fly origin integrity).
7. Build: `xcodebuild -project 4pics1word.xcodeproj -scheme 4pics1word -destination 'platform=iOS Simulator,name=iPhone 16' build`.

## Todo list
- [ ] Rewrite `dayStrip` to 3+3+jackpot
- [ ] Drop redundant `.frame(maxWidth:.infinity)` L109
- [ ] Add `shouldUseJackpotRow` gate
- [ ] Add `jackpotRow` horizontal view
- [ ] Branch `DayTile.body` between `jackpotRow`/`contentColumn`
- [ ] Delete `jackpotBadge` view + overlay ref
- [ ] Verify `todayCellFrameReader` attached both branches
- [ ] `xcodebuild build` green

## Success Criteria
- 3+3+1 layout visible; row-1/row-2 tiles same width.
- Unclaimed Day-7 = full-width horizontal w/ right-anchored JACKPOT pill; golden gradient intact.
- Claimed/locked Day-7 = vertical `contentColumn` (no pill for claimed).
- AX-size (`.accessibility1`/`.accessibility2`) → jackpot vertical.
- Coin-fly still spawns from Day-7 tile when day-7 == today (manual run).
- Build green.

## Risk Assessment
| Risk | Mitigation |
|---|---|
| `todayCellFrameReader` detached from jackpot branch → coin-fly origin = zero | Keep reader in shared overlay chain (L292), not inside branch. |
| iPad regular size class stretches jackpot row absurdly wide | Sheet `.medium` detent bounds it (AppRootView L25). Verify Phase 04 iPad sim. Defer `maxWidth` cap unless visually broken (YAGNI). |
| AX-size horizontal overflow at `.accessibility2` cap | `shouldUseJackpotRow` excludes `isAccessibilitySize` → vertical fallback. |
| `@ScaledMetric cellHeight=96` (L272) jackpot row looks squat | Verify visually; if bad, add `@ScaledMetric jackpotCellHeight: CGFloat = 80` (defer unless needed). |
| `stateOverlay`'s today-ring (L360–362) still draws on horizontal jackpot when day-7 == today | Intended — ring is state cue, layout-agnostic. Keep. |
| Deleting `jackpotBadge` breaks a11y label (L484 jackpot suffix) | No — label is computed from `isJackpot` (L484), not badge. Safe. |

## Security Considerations
None — UI-only change. No data/auth/network surface.

## Next steps
→ Phase 02 (claimed checkmark swap) on same `contentColumn`/`DayTile.body` region.
