# Researcher 01 — Grid + Claimed-state UI

## Files read
- `4pics1word/Views/CheckInView.swift` (574 lines) — `dayStrip` L99–112; `DayTile.body` L275–301; `contentColumn` L305–321; `stateOverlay` L356–385; `jackpotBadge` L398–412; `tileBackground` L334–352.
- `4pics1word/Game/CheckIn.swift` (31 lines) — `rewards = [20,25,30,35,40,50,100]` L4 (idx 6 = jackpot).

## Topic 1: 3-3-1 grid

**Findings**
- Current 4-3 layout (`dayStrip` L102–110): two `HStack(spacing:8)`. Row 2 carries `.frame(maxWidth:.infinity)` (L109) so its 3 tiles already stretch — currently row-2 tiles are **wider** than row-1's 4 tiles (each `DayTile` uses `.frame(maxWidth:.infinity)` at L279, so HStack shares width evenly among its N children). Existing imbalance.
- `LazyVGrid` with 3× `.flexible()` columns: items 1–6 fill rows of 3, but item 7 lands alone in column 0 of row 3 → **not** full-width (left-aligned, 1/3 wide). Would need a separate full-width slot anyway → no win over HStack.
- `Grid` / `GridRow` (iOS 16+): no public colspan API. `GridCell` has no `.span(3)` modifier. Faking it requires nested `HStack`s inside a single `GridRow` cell → identical to the HStack solution with extra ceremony. `Grid`'s win is row/column alignment of heterogeneous cells; here all 6 small cells are identical, so `Grid` adds boilerplate, not value.
- Idiomatic iOS 26 answer is the **manual HStack stack**: it already works today, supports `.accessible` Dynamic Type via `@ScaledMetric` (L272–273), and lets the jackpot row be a structurally different view (free horizontal layout — see Topic 3).

**Recommendation — container hierarchy**
```
VStack(spacing: 12) {              // progressDots wrapper (unchanged)
  progressDots
  VStack(spacing: 8) {             // grid wrapper (L102)
    HStack(spacing: 8) { ForEach(0..<3) }            // days 1–3
    HStack(spacing: 8) { ForEach(3..<6) }            // days 4–6
    dayTile(for: 6).frame(maxWidth: .infinity)       // jackpot, full width
  }
}
```
3+3 rows naturally produce **equal tile widths** (both HStacks have 3 flexible children) — fixes today's 4-vs-3 width mismatch. Drop the `.frame(maxWidth:.infinity)` currently on the 2nd HStack (L109) — it's redundant inside a VStack. The jackpot `DayTile` keeps `.frame(maxWidth:.infinity)` at L279 so it stretches row-wide.

## Topic 2: Claimed-state checkmark + spacing

**Findings**
- `contentColumn` (L307–319) ALWAYS renders the coin `Image` at **L312** (`bitcoinsign.circle.fill` / `gift.fill`). `stateOverlay` then paints a green `checkmark.circle.fill` at **L369** in a ZStack centered over the whole tile — so the coin still shows behind/around the checkmark and the checkmark's center ≠ coin's center (coin sits 4pt under DAY label; checkmark is tile-centered). Visually noisy and misaligned.
- JACKPOT pill (L402) and golden gradient (L336) already gate on `state != .claimed`, so claimed jackpot correctly demotes. Only the coin→checkmark swap is inconsistent.
- `VStack(spacing:4)` (L307): DAY / icon / reward. If we just remove the icon for claimed, the column collapses to DAY + reward with a 4pt gap that looks loose vs. the 3-row tiles. Need a deliberate choice.

**Recommendation**
1. **Swap, don't overlay.** At **L312**, branch on `state == .claimed` → render `Image(systemName:"checkmark.circle.fill")` with `.foregroundStyle(.green)` and the **same `.font(.title3)`** as the coin (NOT `.title` — keeps glyph height identical so the column geometry is unchanged and `VStack(spacing:4)` stays balanced). Delete the `.claimed` case in `stateOverlay` (L367–372) — that ZStack arm becomes dead. Keeps a single source of truth for the icon.
2. **Keep reward number visible on claimed tiles.** Rationale: tells the user "you banked 25"; `valueFont` (L323–330) already drops claimed to `.callout`, so it reads as quieter secondary info. DAY + checkmark + reward with `spacing:4` stays vertically centered because all three rows maintain consistent heights.
3. **Jackpot claimed:** the same swap handles it — `gift.fill` → checkmark; gradient already gone (L336); JACKPOT pill already gone (L402). No special-casing.

Net diff in `contentColumn`: change L312 to a `if state == .claimed { checkmark } else { coin/gift }` branch; net delete in `stateOverlay` (L367–372).

## Topic 3: Day-7 jackpot rich UI

**Recommendation (one approach, KISS)** — make the jackpot `DayTile` use a **horizontal layout** when full-width. Branch at the top of `DayTile.body` (or factor a `JackpotTile` view) so `isJackpot && state != .claimed` renders:
```
HStack(spacing: 10) {
  Image(systemName:"gift.fill").font(.title)             // bigger than .title3
  VStack(alignment:.leading, spacing:2) {
    Text("DAY 7").font(.caption2.weight(.semibold))
    Text("100").font(.title2.weight(.bold)).monospacedDigit()
  }
  Spacer()
  Text("JACKPOT")...Capsule(orange)                       // promoted inline (delete L398–412 badge)
}
.frame(height: cellHeight).frame(maxWidth:.infinity)
```
Why: full-width row earns a left-aligned icon + label cluster and a right-anchored JACKPOT pill (instead of the current topLeading corner pill L409). Single horizontal axis, no new colors, no animation — KISS. Locked/claimed jackpot falls back to the vertical `contentColumn` (preserves visual consistency with days 1–6 once the prize is no longer "active").

Optional flourish (only if time permits): a gentle `symbolEffect(.bounce, options:.repeating)` on `gift.fill` for `state == .today`, gated on `!reduceMotion` (matches existing shimmer gate at L447).

## Risks / gotchas
- **iPad regular size class**: full-width jackpot tile could get very wide on iPad (bottom-sheet max width likely constrains it, but verify sheet's `.presentationDetents`). Consider capping grid container with `.frame(maxWidth: 480)` or `.readableContentGuide`.
- **Dynamic Type up to `.accessibility2`** (capped at L296): horizontal jackpot layout may overflow at AX sizes — either shorten label to "100" only, or fall back to vertical `contentColumn` when `dynamicTypeSize.isAccessibilitySize` (keeps the day-7 promise without truncation).
- **`@ScaledMetric cellHeight=96`** (L272): jackpot full-width tile at 96pt tall may look squat vs. wide; consider a separate `@ScaledMetric var jackpotCellHeight: CGFloat = 80` for the horizontal layout.
- **Reduce Motion**: shimmer (L447) and confetti (L252) already gated. Any new `symbolEffect` on gift.fill must be gated identically.
- **Reduce Transparency** (L270): horizontal jackpot's `Capsule(orange)` solid fill is fine; don't add `.ultraThinMaterial` to the pill.
- **Coin-fly animation** (L213–226): `todayCellFrame` is captured via `todayCellFrameReader` (L470) inside the tile — refactor must keep this reader attached to the jackpot tile when day 7 is today, or the coin-spawn origin breaks.
- **A11y** (L297–300): `accessibilityElement(children:.ignore)` + label is independent of layout — safe across the refactor.

## Unresolved questions
- Sheet's actual max width on iPad / detent — needs the parent presentation site to confirm whether a `maxWidth:480` cap is wanted.
- Whether product wants the reward NUMBER hidden once claimed (assumed no; verify with design).
