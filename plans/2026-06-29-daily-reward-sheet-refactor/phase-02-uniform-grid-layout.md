# Phase 02 — Uniform Grid + Progress Dots

## Context links
- Plan: [../plan.md](../plan.md)
- Research: [../research/researcher-02-report.md](../research/researcher-02-report.md) (§6, §8)
- Prev: [phase-01-lock-sheet-detent.md](./phase-01-lock-sheet-detent.md)
- Source: `4pics1word/Views/CheckInView.swift:101-122` (dayStrip + dayTile), `203-237` (DayTile sizing)
- Next: [phase-03-cell-state-polish.md](./phase-03-cell-state-polish.md)

## Overview
- **Date:** 2026-06-29
- **Description:** Collapse dual-height 3+4 grid → uniform 4+3 (all same height); add 7-dot progress row above grid. Kill `threeHeight/fourHeight`.
- **Priority:** P2
- **Implementation status:** pending
- **Review status:** pending

## Key insights
- Current `DayTileRowSize { three, four }` + `threeHeight:112`/`fourHeight:88` breaks scan rhythm + Dynamic Type (researcher-02 §8). Dual height = visual irregularity + extra code (anti-DRY).
- Uniform grid matches calendar-week metaphor; simpler sizing math.
- 7-across rejected (researcher-02 §8: too narrow on SE 375pt). 4+3 (top row 4, bottom row 3) centered = best fit.
- Progress dots (researcher-02 §6): 7-dot row, filled=claimed / ring=today / hollow=locked. Compact, instant. Place **above** grid (closer to header coin counter = reads as "progress of N").
- Skip: progress bar (implies continuous %), winding path (YAGNI for 7).

## Requirements
### Functional
- F1: 7 cells render in 2 rows — top row 4 cells, bottom row 3 cells — all identical height.
- F2: Bottom row 3 cells centered (equal L/R margins to top row).
- F3: 7-dot progress row renders above grid; dots reflect `claimedCount`, `todayIndex`, locked.
- F4: Jackpot (D7) keeps same cell footprint as D1–D6 (differentiation deferred to Phase 03).

### Non-functional
- NF1: Single `@ScaledMetric` cell height (no `threeHeight`/`fourHeight`).
- NF2: Layout fits `.medium` detent on iPhone SE (375pt) — verify; if overflow, reduce base height.
- NF3: Dynamic Type scales height via `@ScaledMetric`.

## Architecture
Remove `DayTileRowSize` enum + `rowSize` param. DayTile takes single `@ScaledMetric` height.

```swift
// CheckInView.swift — dayStrip rewrite
private var dayStrip: some View {
    VStack(spacing: 12) {
        progressDots            // NEW: 7-dot row
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                ForEach(0..<4, id: \.self) { i in dayTile(for: i) }
            }
            HStack(spacing: 8) {
                ForEach(4..<7, id: \.self) { i in dayTile(for: i) }
            }
            .frame(maxWidth: .infinity)   // center the 3-up row
        }
    }
}

private var progressDots: some View {
    HStack(spacing: 6) {
        ForEach(0..<7, id: \.self) { i in
            Circle()
                .fill(dotFill(for: i))
                .frame(width: 8, height: 8)
        }
    }
}
// dotFill: claimed → .accent, today → .accent stroke ring (Circle().stroke), locked → .secondary.opacity(0.3)
```

DayTile signature change:
```swift
// BEFORE: 6 params incl rowSize; dual heights
// AFTER: drop rowSize, drop threeHeight/fourHeight; single height
@ScaledMetric private var cellHeight: CGFloat = 96   // uniform
private var height: CGFloat { cellHeight }
```

## Related code files
- **Modify:** `4pics1word/Views/CheckInView.swift:101-111` — `dayStrip` (rewrite 3+4 → 4+3 uniform + add `progressDots`).
- **Modify:** `4pics1word/Views/CheckInView.swift:113-122` — `dayTile(for:)` (drop `rowSize` arg).
- **Modify:** `4pics1word/Views/CheckInView.swift:200-201` — delete `DayTileRowSize` enum.
- **Modify:** `4pics1word/Views/CheckInView.swift:203-215` — `DayTile` struct: drop `rowSize`/`threeHeight`/`fourHeight`; add single `cellHeight`.
- **Create:** new private computed property `progressDots` + `dotFill(for:)` helper in `CheckInView`.
- **No change:** `CheckIn.swift`, `AppModel.swift`, `AppRootView.swift`.

## Implementation steps
1. Delete `DayTileRowSize` enum (CheckInView.swift:200-201).
2. In `DayTile`: remove `rowSize` param, `threeHeight`, `fourHeight`, `height` computed; add `@ScaledMetric private var cellHeight: CGFloat = 96`. Set `.frame(height: cellHeight)`.
3. Update `dayTile(for:)` (CheckInView.swift:113-122) — remove `rowSize` arg from `DayTile(...)` init.
4. Rewrite `dayStrip` (CheckInView.swift:101-111): top `ForEach(0..<4)`, bottom `ForEach(4..<7)` in centered HStack. Wrap in outer VStack w/ `progressDots` above.
5. Add `progressDots` View + `dotFill(for index: Int) -> ShapeStyle` helper. Dot states: `index < claimedCount` → filled accent; `index == todayIndex` → ring (stroke); else hollow.
6. Build iPhone 16 sim.
7. **Verify SE fit:** run iPhone SE sim; if 4-up row overflows width, reduce `cellHeight` base or `spacing`. Confirm grid + dots + claim button all fit in `.medium`.
8. Visual sweep: fresh (D1 today), mid-streak (D4 today), D7-claim, fully-claimed-week.

## Todo
- [ ] Delete `DayTileRowSize` enum
- [ ] Remove `rowSize`/`threeHeight`/`fourHeight` from DayTile; add `cellHeight`
- [ ] Update `dayTile(for:)` call site
- [ ] Rewrite `dayStrip`: 4+3 uniform + centered bottom row
- [ ] Add `progressDots` row above grid
- [ ] Add `dotFill(for:)` helper (filled/ring/hollow)
- [ ] Build green iPhone 16 sim
- [ ] SE fit verification (375pt)
- [ ] Visual sweep (fresh/mid/D7/claimed)

## Success criteria
- 7 cells identical height; bottom 3 centered under top 4.
- `threeHeight`/`fourHeight`/`DayTileRowSize` gone (grep confirms no references).
- 7-dot row renders; dots reflect claim/today/locked state in real time.
- Grid + dots + header + claim button fit `.medium` on SE without scroll.
- Dynamic Type XL scales cells uniformly (no row mismatch).

## Risk assessment
| Risk | Likelihood | Mitigation |
|---|---|---|
| SE `.medium` too short for 4+3 + dots + button | Med | Reduce `cellHeight` base (96→84); verify Phase 01 `.fraction(0.6)` fallback |
| 4-up cells too narrow at AX2 + SE | Med | Phase 03 caps at `.accessibility2`; verify value text min-width |
| Dot ring (stroke) invisible on reduce-transparency | Low | Use opaque `.secondary` fallback |
| Centered 3-up row misaligns w/ 4-up column edges | Low | Acceptable (calendar metaphor); or align leading if design objects |

## Security considerations
None. Layout only.

## Next steps
→ Phase 03 (cell state polish). Builds on uniform cell: soft locked, jackpot gift.fill, shimmer, a11y2 cap, VoiceOver labels.

## Unresolved questions
1. `cellHeight` base value — 96pt assumed; needs SE + iPhone 16 empirical tune. 4-up at 375pt: `(375 - 32 padding - 24 gaps)/4 ≈ 80pt` width. Square-ish cells → height ≈ width. Reconsider: maybe `cellHeight` should derive from width via GeometryReader? Default: fixed `@ScaledMetric` (KISS); revisit if overflow.
2. Progress dots position — above grid (default) vs below claim button? Above reads as "week progress"; below reads as "step counter". Default above.
3. Should dots be tappable (jump-scroll)? No — locked cells aren't claimable (YAGNI).
