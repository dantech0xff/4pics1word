# Phase 02 — Two-row grid 3/4 layout

## Context links
- Plan: [../plan.md](../plan.md)
- Research: [../research/researcher-02-report.md](../research/researcher-02-report.md) (§1, §3)
- Prev phase: [phase-01-force-claim-dismiss-gate.md](./phase-01-force-claim-dismiss-gate.md)
- Next phase: [phase-03-enriched-daytile.md](./phase-03-enriched-daytile.md)

## Overview
- **Date:** 2026-06-28
- **Description:** Replace single 7-cell HStack with VStack[HStack(1-3), HStack(4-7)], centered. User chose 3/4 over researcher's 3+3+1 recommendation — non-negotiable.
- **Priority:** P2
- **Implementation status:** pending
- **Review status:** pending

## Key insights
- User explicitly rejected researcher-02 §1 verdict (3+3+1 banner). **Respect 3/4.** Don't second-guess.
- 3-up cells get more room than 4-up — DayTile sizing must be parametric (Phase 03).
- Center each HStack via `.frame(maxWidth: .infinity, alignment: .center)` — HStack naturally distributes cells.
- Reduce horizontal padding 20→16 (per researcher-02 §3) so 4-up row has breathing room.
- Avoid `GeometryReader` (KISS) — `@ScaledMetric` + `frame(maxWidth:.infinity)` distributes equally.

## Requirements
1. `dayStrip` (currently single HStack L82-95) → VStack containing two HStacks.
2. Row 1: indices 0,1,2 (Days 1–3). Row 2: indices 3,4,5,6 (Days 4–7).
3. Both rows centered horizontally. Each cell `.frame(maxWidth: .infinity)` for equal distribution.
4. Row spacing 8–10pt; cell spacing 8pt within row (existing).
5. Outer `.padding(.horizontal, 20)` → `.padding(.horizontal, 16)` (researcher-02 §3).
6. Keep `.accessibilityElement(children: .contain)` on container.
7. `tileState(for:)` iteration unchanged — still 0..<7.

## Architecture
Pure layout swap. No new types, no new state. DayTile signature stable (Phase 03 adds params).

```swift
private var dayStrip: some View {
    VStack(spacing: 10) {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { i in dayTile(for: i) }
        }
        HStack(spacing: 8) {
            ForEach(3..<7, id: \.self) { i in dayTile(for: i) }
        }
    }
    .accessibilityElement(children: .contain)
}

private func dayTile(for i: Int) -> some View {
    DayTile(
        day: i + 1,
        reward: CheckIn.rewards[i],
        state: tileState(for: i),
        isJackpot: i == 6,
        pulse: pulse
    )
}
```

## Related code files
- `4pics1word/Views/CheckInView.swift:82-95` — `dayStrip` (replace).
- `4pics1word/Views/CheckInView.swift:46` — `.padding(.horizontal, 20)` → `16`.
- `4pics1word/Views/CheckInView.swift:97-101` — `tileState(for:)` (no change; just confirm 0..<7 indexing).
- `4pics1word/Game/CheckIn.swift:4` — `rewards` array [20,25,30,35,40,50,100] (D7=jackpot, idx 6 → row 2).

## Implementation steps
1. Extract `dayTile(for:)` helper (DRY — used 7× currently inline).
2. Replace `dayStrip` body: VStack[HStack(0..<3), HStack(3..<7)].
3. Change outer padding 20→16.
4. Build, eyeball on iPhone 16 sim — verify both rows centered, Day 7 last in row 2.
5. Verify `actionSection` + `Spacer(minLength: 8)` (L43) still fit at `.medium` detent.

## Todo
- [ ] Extract `dayTile(for:)` helper
- [ ] Replace `dayStrip` with VStack of 2 HStacks
- [ ] Reduce horizontal padding 20→16
- [ ] Verify `.medium` detent doesn't clip (action button visible)
- [ ] Visual sanity check on iPhone 16 + iPad mini

## Success criteria
- Two rows visible. Row 1 has 3 cells, row 2 has 4 cells.
- Both rows centered horizontally (not stretched to edges).
- Day 7 (jackpot) is the 4th cell of row 2.
- No horizontal scroll, no clipping on smallest device width (iPhone SE 375pt).
- Existing a11y traversal order preserved (D1 → D7 top-to-bottom).

## Risk assessment
| Risk | Likelihood | Mitigation |
|---|---|---|
| `.medium` detent now too short for 2 rows + action | Med | Tile sizing tuned in Phase 03; if needed bump shortest detent to `.large`-only |
| 4-up cells too cramped on SE (375pt) | Med | `@ScaledMetric` floor + verify in Phase 03 |
| A11y order regression | Low | `accessibilityElement(children: .contain)` keeps source order |

## Security considerations
None. Pure layout.

## Next steps
→ Phase 03 (enriched DayTile). Cell sizing parameters feed back into Phase 02 layout — tune iteratively.
