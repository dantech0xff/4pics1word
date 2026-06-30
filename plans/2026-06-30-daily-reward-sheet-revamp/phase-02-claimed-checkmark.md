# Phase 02 — Claimed Checkmark-Only + Spacing Balance

## Context links
- Parent plan: `../plan.md`
- Dependency: Phase 01 (shares `contentColumn` / `DayTile.body`).
- Research: `../research/researcher-01-report.md` (§2 claimed-state).
- Scout: `../scout/scout-01-report.md` (L305–321 contentColumn, L356–385 stateOverlay).
- Source: `4pics1word/Views/CheckInView.swift`.

## Overview
- Date: 2026-06-30
- Description: Stop showing coin behind checkmark on claimed tiles. Branch `contentColumn` icon (L312) on `state == .claimed` → green checkmark (same `.title3`); delete dead overlay arm (L367–372). Reward number stays.
- Priority: P2
- Implementation status: pending
- Review status: pending

## Key Insights (researcher-01 §2)
- `contentColumn` (L307–319) ALWAYS renders coin `Image` at L312. `stateOverlay` then paints green `checkmark.circle.fill` at L369 in tile-centered ZStack → coin still visible behind/around checkmark; checkmark center ≠ coin center (coin sits 4pt under DAY label, checkmark tile-centered). Noisy + misaligned.
- Using same `.font(.title3)` for checkmark keeps glyph height == coin → `VStack(spacing:4)` (L307) geometry unchanged → column stays vertically centered w/ DAY + check + reward.
- Reward number stays on claimed: tells user "banked 25"; `valueFont` (L327 `.callout`) already quiets it.
- Jackpot claimed handled by same swap (`gift.fill` → checkmark); gradient already gone (L336), pill already gone (Phase 01). No special-case.
- Single source of truth for icon = `contentColumn`. Overlay's `.claimed` arm (L367–372) becomes dead → delete.

## Requirements
1. Claimed tile: ONLY green checkmark icon (no coin/gift behind).
2. DAY label + checkmark + reward number remain; `VStack(spacing:4)` visually balanced/centered.
3. Checkmark glyph height == coin glyph height (same `.title3`).
4. `stateOverlay`'s `.claimed` arm removed (no overlay checkmark).
5. Jackpot claimed: same swap (no special-case).
6. A11y label (L483–496) unchanged.

## Architecture

### `contentColumn` icon branch (L312)
Replace single `Image(systemName: isJackpot ? "gift.fill" : "bitcoinsign.circle.fill")…` with:
```swift
if state == .claimed {
    Image(systemName: "checkmark.circle.fill")
        .font(.title3)                       // SAME as coin → geometry unchanged
        .foregroundStyle(.green)
} else {
    Image(systemName: isJackpot ? "gift.fill" : "bitcoinsign.circle.fill")
        .font(.title3)
        .foregroundStyle(isJackpot ? .white : .yellow)
}
```
`VStack(spacing: 4)` (L307) unchanged — 3 rows maintain consistent heights → stays centered.

### `stateOverlay` — delete `.claimed` arm (L367–372)
Remove the `case .claimed: Image(systemName:"checkmark.circle.fill")…` block. `stateOverlay` keeps `.today` (ring L360–362) + `.locked` (lock chip L374–383) only.

## Related code files
- `4pics1word/Views/CheckInView.swift` — L305–321 (`contentColumn`), L356–385 (`stateOverlay`), L323–330 (`valueFont` unchanged), L483–496 (a11y unchanged).

## Implementation Steps
1. L312: replace `Image(systemName: isJackpot ? …)` w/ `if state == .claimed { checkmark } else { coin/gift }` branch (see Architecture).
2. L367–372: delete `case .claimed:` arm in `stateOverlay` switch.
3. Build: `xcodebuild -project 4pics1word.xcodeproj -scheme 4pics1word -destination 'platform=iOS Simulator,name=iPhone 16' build`.
4. Manual: claim a reward → claimed tile shows green check only (no coin behind); DAY + check + number vertically centered.

## Todo list
- [ ] Branch `contentColumn` L312 on `state == .claimed`
- [ ] Checkmark uses `.title3` + `.green`
- [ ] Delete `.claimed` arm in `stateOverlay` (L367–372)
- [ ] Verify claimed jackpot demotes (gradient/pill already gone)
- [ ] `xcodebuild build` green

## Success Criteria
- Claimed tiles (days 1–6 + jackpot): ONLY green checkmark, no coin/gift behind.
- DAY + checkmark + reward number evenly spaced (4pt); vertically centered in tile.
- No checkmark overlay (single source of truth in `contentColumn`).
- Unclaimed tiles unchanged (coin/gift as before).
- Build green.

## Risk Assessment
| Risk | Mitigation |
|---|---|
| Checkmark looks smaller/larger than coin → column shift | Pin `.font(.title3)` identical to coin (L313). Verify visually. |
| `stateOpacity` 0.7 (L439) dims checkmark too much on claimed | Existing behavior; checkmark green still readable at 0.7. If not, exempt claimed from opacity (defer). |
| Reward number on claimed feels redundant | Intentional (keeps "banked N" info); `valueFont` `.callout` quiets it. Keep. |
| Jackpot claimed: gradient/pill assumed gone | Phase 01 deletes pill; `tileBackground` L336 already gates `state != .claimed`. Confirm after Phase 01 lands. |

## Security Considerations
None — UI-only. No data/auth/network surface.

## Next steps
→ Phase 03 (countdown action section) on disjoint `actionSection` region (L156–182).
