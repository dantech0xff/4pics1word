# Phase 01 — Hero-zoom viewer + credits (core)

## Context links
- Parent plan: [../plan.md](../plan.md)
- Depends on: research/researcher-01-report.md, scout/scout-01-report.md
- Spec / conventions: `AGENTS.md` (module `_pics1word`, synced groups, MainActor default, default SwiftUI only)

## Overview
- Date: 2026-06-28
- Description: Wire tap-to-zoom on the 4 puzzle pictures with a `matchedGeometryEffect` hero animation and a credit caption.
- Priority: P2
- Implementation status: done
- Review status: done
- **Revision (2026-06-28):** zoomed image fills the **grid area only** (`.overlay` on `PictureGrid`), NOT fullscreen; no black backdrop. The zoomed cell renders `Color.clear` to keep the 2×2 grid shape stable. See `plan.md`.

## Key Insights
- Hero zoom **requires a ZStack overlay** in the same view hierarchy as the grid — `.fullScreenCover`/`.sheet` break `matchedGeometryEffect` (researcher-01 §1).
- Only **one view per matchedGeometry id** at a time → conditionally hide the source cell while it is zoomed (`if zoomedIndex != index`), else SwiftUI logs a runtime warning (researcher-01 §1).
- Animate the **state mutation**, not the view: `withAnimation(.spring(...)) { zoomedIndex = x }` gives symmetric zoom-in/out (researcher-01 §3).
- `Puzzle.copyrights` is `[String]` with exactly 4 entries → credit for image `index` is `copyrights[index-1]` (scout-01).
- `GameView.body` is a `VStack` → must wrap in `ZStack` so the overlay sits above the nav bar / letter bank (scout-01).
- `PuzzleImage(puzzleId:index:)` is resizable and cached → reuses cleanly at fullscreen size.

## Requirements
- R1: Tap a picture cell → that image animates (zoom-in) to fullscreen, edge-to-edge, above all other UI.
- R2: Show the image's credit (from `copyrights[index-1]`) legibly over the photo.
- R3: Tap the fullscreen image → animates (zoom-out) back into its cell.
- R4: Zoom-in and zoom-out both animate (spring).
- R5: No matchedGeometry duplicate-id runtime warnings.
- R6: Default SwiftUI only; honor `AGENTS.md` (no custom drawing, MainActor default).

## Architecture
- `GameView` owns state: `@Namespace private var zoomNS`, `@State private var zoomedIndex: Int?`. Root becomes `ZStack { VStack {…}; if let i = zoomedIndex { ImageZoomOverlay(…) } }`.
- `PictureGrid` becomes parameterized: `(puzzleId:, zoomedIndex:, namespace:, onTap: (Int)->Void)`. Each cell wrapped in a `Button` (a11y) with `.matchedGeometryEffect(id: "puzzle-img-\(index)", in: namespace)`; cell body only renders when `zoomedIndex != index`.
- NEW `Components/ImageZoomOverlay.swift`: fullscreen `PuzzleImage` (same matchedGeometry id), black backdrop `.ignoresSafeArea()`, credit `Capsule` pill at bottom, tap to dismiss.

## Related code files
- `4pics1word/Components/PictureGrid.swift` (edit) — currently `struct PictureGrid { let puzzleId: Int }` (PictureGrid.swift:4-5).
- `4pics1word/Views/GameView.swift` (edit) — body outermost is `VStack(spacing:16)` (GameView.swift:14); `state.puzzle.copyrights` accessible; passes `puzzleId` to grid at ~GameView.swift:57.
- `4pics1word/Components/PuzzleImage.swift` (read-only reuse) — `PuzzleImage(puzzleId:index:)`.
- `4pics1word/Components/ImageZoomOverlay.swift` (NEW).

## Implementation Steps
1. Create `Components/ImageZoomOverlay.swift`: props `index: Int`, `puzzleId: Int`, `credit: String?`, `namespace: Namespace.ID`, `onDismiss: () -> Void`. Body: `ZStack { Color.black.ignoresSafeArea(); PuzzleImage(puzzleId:puzzleId,index:index).matchedGeometryEffect(id:"puzzle-img-\(index)", in:namespace).aspectRatio(1, contentMode:.fit)… ; creditPill }`. Whole ZStack `.onTapGesture { onDismiss() }` (or `Button`).
2. Edit `PictureGrid.swift`: add `zoomedIndex: Int?`, `namespace: Namespace.ID`, `onTap: (Int)->Void`. For each `index` in 1…4: `if zoomedIndex != index { Button { onTap(index) } label: { PuzzleImage(…).matchedGeometryEffect(id:"puzzle-img-\(index)", in:namespace) …existing aspectRatio/clipShape } }`.
3. Edit `GameView.swift`: add `@Namespace private var zoomNS`, `@State private var zoomedIndex: Int?`. Wrap root in `ZStack(alignment: .top)`. After the `VStack`, add `if let i = zoomedIndex { ImageZoomOverlay(index:i, puzzleId:state.puzzle.id, credit: credit(for:i), namespace:zoomNS) { dismissZoom() } }`.
4. Add helpers in `GameView`: `private func zoom(_ i: Int) { withAnimation(.spring(response:0.42, dampingFraction:0.78)) { zoomedIndex = i } }`; `private func dismissZoom() { withAnimation(.spring(response:0.42, dampingFraction:0.78)) { zoomedIndex = nil } }`; `private func credit(for i:Int) -> String? { let c = state.puzzle.copyrights; return c.indices.contains(i-1) ? c[i-1] : nil }`. Pass `onTap: zoom` to `PictureGrid`.
5. Wire `PictureGrid(puzzleId:state.puzzle.id, zoomedIndex:zoomedIndex, namespace:zoomNS, onTap: zoom)`.

## Todo list
- [x] Create `ImageZoomOverlay.swift`
- [x] Parameterize `PictureGrid` (zoomedIndex/namespace/onTap) + matchedGeometry on cells
- [x] Add `@Namespace` + `@State zoomedIndex` to `GameView`
- [x] Wire zoom/dismiss helpers with spring animation + credit lookup
- [x] Build clean; run unit tests (36/36 unchanged)

## Success Criteria
- Tap each of the 4 pictures → zooms to fullscreen showing the right credit; tap → zooms back.
- No console matchedGeometry warnings.
- `xcodebuild build` succeeds; `4pics1wordTests` 36/36 pass.

## Risk Assessment
- **Med — duplicate matchedGeometry id**: mitigated by conditional cell rendering (R5). Verify no runtime warning in console.
- **Low — overlay clipping**: ZStack at root + `.ignoresSafeArea()` on backdrop ensures edge-to-edge over nav bar.
- **Low — credit missing**: bounds-guarded (R2).

## Security Considerations
- None. No network, no untrusted input. Credits are read-only bundle data.

## Next steps
- Proceed to phase-02 (a11y, motion-reduce gating, manual/UI verification).
