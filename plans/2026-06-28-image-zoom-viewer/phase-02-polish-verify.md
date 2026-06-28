# Phase 02 — Polish: accessibility, motion-reduce, verify

## Context links
- Parent plan: [../plan.md](../plan.md)
- Depends on: [phase-01-hero-zoom-viewer.md](./phase-01-hero-zoom-viewer.md), research/researcher-01-report.md

## Overview
- Date: 2026-06-28
- Description: Harden the zoom viewer for accessibility, respect Reduce Motion, style the credit, and verify end-to-end.
- Priority: P2
- Implementation status: done
- Review status: done
- **Revision (2026-06-28):** credit pill is bottom-right **inside** the enlarged image (grid-area overlay); hint bar / answer slots / letter bank stay visible AND interactive while zoomed.

## Key Insights
- `accessibilityReduceMotion` should bypass the spring (use instant or `.snappy` low-response) per researcher-01 §6.
- Prefer `Button` + `.accessibilityLabel` over raw `.onTapGesture` for the cell and the fullscreen layer (scout-01 unresolved Q).
- Add `.accessibilityAction(named: "Dismiss")` to the fullscreen layer so VoiceOver users can close it deliberately.
- Credit pill: `Capsule().fill(.black.opacity(0.45))` (or `.ultraThinMaterial`) behind white caption; animate it via its own `.transition(.opacity)` so it doesn't fight the matched-geometry frame animation (researcher-01 §4).

## Requirements
- R7: Reduce Motion → zoom is instant (no spring) on both directions.
- R8: Each picture cell has a descriptive `accessibilityLabel` (e.g. "Picture 1 of 4, tap to enlarge").
- R9: Fullscreen layer has `accessibilityLabel` + `accessibilityAction(.named("Dismiss"))`.
- R10: Credit is legible on any photo (pill background), centered at bottom, does not animate its frame with the hero.
- R11: Verified via build + unit suite + a UI smoke (tap → credit appears → tap → gone).

## Architecture
- In `GameView.zoom/dismissZoom`: read `@Environment(\.accessibilityReduceMotion)`; if true, mutate without `withAnimation` (or use `.linear(duration: 0.05)`).
- In `ImageZoomOverlay`: separate the credit pill into its own animated element with `.transition(.opacity)` independent of the matched-geometry image.

## Related code files
- `4pics1word/Components/ImageZoomOverlay.swift` (edit) — a11y + credit styling.
- `4pics1word/Components/PictureGrid.swift` (edit) — cell `accessibilityLabel`.
- `4pics1word/Views/GameView.swift` (edit) — Reduce Motion gating.
- Optional: `4pics1wordUITests/ImageZoomUITests.swift` (NEW) — UI smoke.

## Implementation Steps
1. Add `@Environment(\.accessibilityReduceMotion) var reduceMotion` to `GameView`; gate the spring in `zoom(_:)` / `dismissZoom()`.
2. Add `.accessibilityLabel("Picture \(index) of 4")` + `.accessibilityHint("Tap to enlarge")` to each `PictureGrid` cell.
3. Add `.accessibilityElement(children: .combine)` + label + `.accessibilityAction(.named("Dismiss")) { onDismiss() }` to `ImageZoomOverlay`.
4. Style the credit pill: `Capsule().fill(.black.opacity(0.45))` padding, white `.footnote` text; wrap in `.transition(.opacity)`; credit text shows "© \(credit)".
5. (Optional) Add `ImageZoomUITests.swift`: tap cell → assert credit text appears; tap → assert it disappears.
6. Final: `xcodebuild build` + `4pics1wordTests` 36/36.

## Todo list
- [x] Gate spring on `accessibilityReduceMotion`
- [x] Cell + overlay accessibility labels and dismiss action
- [x] Credit pill styling (bottom-right inside image) + opacity transition
- [x] UI smoke test (zoom + hint-bar-visible + other-cells-covered + dismiss)
- [x] Build + unit suite green; UI test green

## Success Criteria
- Reduce Motion on → instant show/hide; off → spring zoom both ways.
- VoiceOver can open and dismiss the viewer; credits announced.
- Credit legible on bright and dark photos.
- Build + 36 unit tests green.

## Risk Assessment
- **Low — spring gating bugs**: trivial boolean; verify with Reduce Motion toggle in sim settings.
- **Low — a11y element grouping**: combine children so the tap target + label are coherent.

## Security Considerations
- None.

## Next steps
- After review/approval, implement. Suggest `/clear` then implement phase 01 then 02.
