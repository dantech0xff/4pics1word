# Phase 01 — Lock Sheet Detent

## Context links
- Plan: [../plan.md](../plan.md)
- Research: [../research/researcher-01-report.md](../research/researcher-01-report.md) (§2, §3, §4, §5)
- Source: `4pics1word/Views/AppRootView.swift:23-28`
- Next: [phase-02-uniform-grid-layout.md](./phase-02-uniform-grid-layout.md)

## Overview
- **Date:** 2026-06-29
- **Description:** Single `.medium` detent — kill drag-to-fullscreen. 1-line modifier change + iPad verification.
- **Priority:** P2
- **Implementation status:** pending
- **Review status:** pending

## Key insights
- Multiple detents = multiple snap stops = expandable by design (researcher-01 §2). Two detents `[.medium, .large]` is the root cause of bug.
- Single `[.medium]` removes the expand target — upward drag has nowhere to snap. Does NOT disable swipe-down dismiss (that's `.interactiveDismissDisabled`).
- Drag indicator is cosmetic only — `.presentationDragIndicator(.hidden)` does NOT lock. Keep `.visible` (swipe-down affordance still valid).
- `.interactiveDismissDisabled(!model.canCheckInToday)` blocks dismissal only, not resizing — irrelevant to expansion once single-detent, but keep (claim gate).
- **iPad:** `.presentationDetents` ignored in regular size class (form-sheet, resize grabber). No public lock API. **Accept.**

## Requirements
### Functional
- F1: Sheet cannot expand to fullscreen on iPhone (no drag-to-`.large`).
- F2: Swipe-down dismiss still works when `model.canCheckInToday == false`.
- F3: Swipe-down dismiss blocked when `model.canCheckInToday == true` (existing gate preserved).
- F4: Drag indicator visible.

### Non-functional
- NF1: Zero logic changes (no `CheckIn.swift`/`AppModel.swift` edits).
- NF2: Build green iPhone 16 sim.

## Architecture
1-line modifier change. No new types.

```swift
// AppRootView.swift:25 — BEFORE
.presentationDetents([.medium, .large])

// AFTER
.presentationDetents([.medium])
```
Keep `.presentationDragIndicator(.visible)` (L26), `.interactiveDismissDisabled(!model.canCheckInToday)` (L27) unchanged.

## Related code files
- **Modify:** `4pics1word/Views/AppRootView.swift:25` — detent set.
- **No change:** `AppRootView.swift:26-27` (indicator + dismiss gate).
- **No change:** `CheckInView.swift`, `CheckIn.swift`, `AppModel.swift`.

## Implementation steps
1. Open `AppRootView.swift`.
2. Change L25 `.presentationDetents([.medium, .large])` → `.presentationDetents([.medium])`.
3. Verify L26-27 unchanged.
4. Build iPhone 16 sim: `xcodebuild -project 4pics1word.xcodeproj -scheme 4pics1word -destination 'platform=iOS Simulator,name=iPhone 16' build`.
5. Manual sim test: open sheet (fresh launch), attempt drag-up — confirm no expand. Drag-down pre-claim — confirm blocked. Post-claim drag-down — confirm closes.
6. **iPad verification:** run on iPad sim; confirm `[.medium]` ignored (form-sheet), grabber present. Document observed behavior in reports/.
7. Run existing UI tests — all should still pass (no contract change).

## Todo
- [ ] Change detent to `[.medium]` (AppRootView.swift:25)
- [ ] Build green iPhone 16 sim
- [ ] Manual: drag-up no expand (iPhone)
- [ ] Manual: dismiss gate intact pre/post claim
- [ ] iPad sim: confirm form-sheet behaviour (document, do not "fix")
- [ ] Existing UI tests green

## Success criteria
- iPhone: drag-up on sheet produces no fullscreen expansion.
- Dismiss gate (`interactiveDismissDisabled`) behaves identically pre/post change.
- iPad: acknowledged form-sheet (no regression vs prior).
- `xcodebuild build` + `test` green.

## Risk assessment
| Risk | Likelihood | Mitigation |
|---|---|---|
| SE (375pt) `.medium` too short for 7 cells + button | Med | Verify in Phase 02; if cramped use `.fraction(0.6)` single detent (still non-expandable) |
| iPad users expect full sheet | Low | Pre-existing behaviour; no regression. Accept. |
| `.large` removal breaks a test asserting 2 detents | Low | No such test exists (UI tests assert on elements not detents). |

## Security considerations
None. Pure presentation modifier.

## Next steps
→ Phase 02 (uniform grid + progress dots). Builds cell layout inside the now-locked `.medium` sheet.

## Unresolved questions
1. SE fit confirmation deferred to Phase 02 (layout-dependent).
2. Whether to add `.presentationContentInteraction(.resizes)` (iOS 17+) — researcher-01 §2 notes no-op for single-detent expansion; skip unless scroll-conflict observed (YAGNI now).
