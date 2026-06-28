---
title: "Fullscreen image viewer with hero zoom + credits"
description: "Tap a puzzle picture to hero-zoom it fullscreen with its photo credit; tap again to zoom back."
status: approved
priority: P2
effort: 3h
branch: master
tags: [swiftui, ui, animation, gameview]
created: 2026-06-28
validated: 2026-06-28
---

# Plan — Fullscreen image viewer with hero zoom + credits

## Goal
When the player taps one of the 4 puzzle pictures in `GameView`, that image zooms up from its grid cell to fill the **whole 2×2 grid area** (not the screen) and shows its photo credit as a pill in the image's bottom-right. The hint bar, answer slots, and letter bank stay visible and interactive underneath. Tap the enlarged image to zoom it back into its cell. Zoom-in and zoom-out both animate.

## Approach (decided, revised 2026-06-28)
Hero animation via `matchedGeometryEffect`. The zoomed image lives in a **`.overlay` on `PictureGrid`'s `LazyVGrid`** (grid-box-sized, not fullscreen; no black backdrop). One source of truth: `@State zoomedIndex: Int?` in `GameView`. The zoomed cell renders `Color.clear` in its slot to keep the grid's 2×2 shape stable; the overlay is the sole holder of the matched-geometry id. Animate the state mutation with `withAnimation(.spring(...))` so zoom-in/out are symmetric. Dismiss = tap the enlarged image; the rest of the UI stays interactive.

## Scope / non-goals
- In: tap-to-zoom, zoom-in/out animation, credit caption per image, tap-to-dismiss, accessibility.
- Out: pinch-to-zoom, pan, swipe-to-dismiss, video, sharing.

## Phases
| # | Phase | Status | Progress | File |
|---|---|---|---|---|
| 01 | Hero-zoom viewer + credits (core) | done | 100% | [phase-01-hero-zoom-viewer.md](./phase-01-hero-zoom-viewer.md) |
| 02 | Polish: a11y, motion-reduce, verify | done | 100% | [phase-02-polish-verify.md](./phase-02-polish-verify.md) |

## Key risks
- **Duplicate matchedGeometry id warning** if the zoomed cell and the overlay both render with the same id → mitigated by rendering `Color.clear` in the zoomed cell's slot (id removed); only the overlay carries the id.
- **Grid reflow while zoomed** → mitigated by `Color.clear.aspectRatio(1,.fit)` reserving the square slot; grid bbox stays square, overlay target frame is stable.
- **Credit bounds**: `Puzzle.copyrights` has 4 entries; guard `index-1` regardless.

## Definition of done
- Tap any of the 4 pictures → smooth zoom to grid-area size with its credit pill (bottom-right); tap → smooth zoom back.
- Hint bar, answer slots, letter bank stay visible AND interactive while zoomed.
- Build clean; 36 existing unit tests still green; UI test green; no matchedGeometry runtime warnings.

## Validated decisions (2026-06-28; revised for grid-area UX)
- Zoom size: **grid area only** (2×2 footprint), NOT fullscreen. No black backdrop.
- Other UI: **stays interactive** while zoomed (peek-while-playing).
- Dismiss: **tap the enlarged image**.
- Pinch-to-zoom / pan: **out of scope**.
- Credit: **bottom-right pill inside the image**.
- Animation: **spring(response: 0.42, dampingFraction: 0.78)**; gate on `accessibilityReduceMotion`.
