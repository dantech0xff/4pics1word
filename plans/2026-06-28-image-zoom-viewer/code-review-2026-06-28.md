# Code Review — Image Zoom Viewer refactor (fullscreen → grid-area-only)

**Date:** 2026-06-28
**Scope:** `PictureGrid.swift`, `ImageZoomOverlay.swift`, `GameView.swift`, `ImageZoomUITests.swift`
**Context read:** `PuzzleImage.swift`, `AppRootView.swift`, `LetterBank.swift`, `AnswerSlots.swift`, `TileButton.swift`, `Models.swift`
**Verification trusted per request:** build clean, 36/36 unit green, ImageZoomUITests pass — NOT re-run.

## Scope
- Files reviewed: 4 changed + 6 context
- LoC analyzed: ~225 (changed) + ~250 (context)
- Focus: matchedGeometry correctness, layout stability, hit-testing, credit pill, state/closures, a11y, style consistency
- Updated plans: NONE (user said "do NOT edit anything"); **stale plan flagged below as MAJOR-1**

## Overall Assessment
Sound refactor. The hero-zoom pattern is implemented correctly: the source cell drops its `matchedGeometryEffect` when zoomed (replaced by `Color.clear.aspectRatio(1,.fit)`), the grid `.overlay` provides the target, and the shared namespace carries the prior frame. No duplicate-id risk, grid stays square, siblings remain interactive. No critical code issues. The only real blocker is **stale planning docs** that contradict the shipped grid-area-only behavior.

## CRITICAL (must fix)
None. Code is correct and safe to ship.

## MAJOR (should fix)

### MAJOR-1 — Plan & phase docs describe the OLD fullscreen design (`plans/2026-06-28-image-zoom-viewer/`)
- `plan.md:3,16,36,41,46` still say "fullscreen", "fills the screen (over the nav bar)", "fullscreen layer", "tap anywhere on backdrop/image".
- `phase-01-hero-zoom-viewer.md:24,26,34,43,57,63` specify `Color.black.ignoresSafeArea()` backdrop, edge-to-edge over nav bar — none of which shipped.
- `plan.md:30-33` marks both phases `done | 100%`, but `phase-02-polish-verify.md:11,46-50` says "Implementation status: pending" with **all todos still `[ ]`**.
- **Impact:** any agent or human re-entering this plan will rebuild the wrong (fullscreen) thing, or believe phase-02 is unfinished. Directly contradicts shipped behavior.
- **Fix:** Update `plan.md` (title/description/goal/key-risks/definition-of-done) to "grid-area-only"; mark phase-02 todos `[x]` and status `done`; rewrite `phase-01` architecture section to match (`PictureGrid` owns `.overlay`, no `ZStack{Color.black}`, no `ignoresSafeArea`). Add a one-line note: *"Refactored from fullscreen → grid-area-only on 2026-06-28; hint bar/slots/bank stay interactive."*

## MINOR (nice to have)

### MINOR-1 — Credit pill rides the hero frame, violating phase-02 R10 intent — `ImageZoomOverlay.swift:21-32`
- `.transition(.opacity)` only fires when the `if let credit` conditional flips. Credit is non-nil for the whole zoom, so the pill is present at t=0 at the **source cell's** small frame and scales up with the image. Phase-02 R10 explicitly wanted the credit **not** to animate its frame with the hero.
- **Fix (optional):** defer the pill with `.transition(.opacity.animation(.easeOut.delay(0.15)))`, or wrap in `if !isAppearing` tied to a `@State` set in `onAppear`. Low impact — current behavior is acceptable.

### MINOR-2 — Shadow pops at zoom start — `PictureGrid.swift:49` vs `ImageZoomOverlay.swift:20`
- Source cell has `.shadow(color:.black.opacity(0.1), radius:2, y:1)`; overlay has none. At zoom-start the shadow vanishes abruptly.
- **Fix:** either drop the shadow on cells too, or add the same shadow to `ImageZoomOverlay`'s clipped image. Cosmetic.

### MINOR-3 — Redundant `.accessibilityElement(children:.combine)` on a Button — `ImageZoomOverlay.swift:36`
- A `Button` is already a single a11y element; `.combine` is a no-op here. Harmless noise.
- **Fix:** delete the line; keep `.accessibilityLabel/_hint/_action`.

### MINOR-4 — Spring config diverges from app convention — `GameView.swift:136`
- `LetterBank.swift:21` and `AnswerSlots.swift:17` use `.snappy`; zoom uses `.spring(response:0.42, dampingFraction:0.78)`. Defensible (hero warrants a custom spring) but inconsistent. Note only.

### MINOR-5 — a11y label punctuation drift — `PictureGrid.swift:53` vs `ImageZoomOverlay.swift:43-45`
- Cell: `"Picture 1 of 4"` (no terminal period). Overlay: `"Picture 1, enlarged. Credit: …"`. Nit; pick one convention.

### MINOR-6 — UI test gap: doesn't assert the 3 non-zoomed cells are not tappable while zoomed — `ImageZoomUITests.swift`
- Covers cell-hide, hint-bar-visible, dismiss. Doesn't verify hit-testing isolation under the overlay. Add `XCTAssertFalse(app.buttons["Picture 2 of 4"].isHittable)` while zoomed.

## Positive Observations
- **matchedGeometry is textbook:** source removed via `if zoomedIndex == index` branch (PictureGrid.swift:37-40), single id per namespace, **no duplicate-id warning possible**. `ImageZoomOverlay.matchedGeometryId(for:)` is the single source of truth (ImageZoomOverlay.swift:49) — good.
- **Grid stays square:** `Color.clear.aspectRatio(1,.fit)` reserves a square slot matching siblings; grid bbox is exactly square (`gridHeight = 2·(W-8)/2 + 8 = W`), so the `.overlay` is a true square and the zoomed `aspectRatio(1,.fit)` image fills it edge-to-edge. No reflow risk.
- **1:1 source/target aspect** means `PuzzleImage`'s internal `.scaledToFill()` produces identical crops at both sizes → no crop-shift jitter during the hero.
- **Hit-testing correct:** overlay Button (W×W) covers all 4 cells (the 3 non-zoomed are intentionally not tappable); siblings in the VStack (hint bar / AnswerSlots / LetterBank) are outside the overlay and stay interactive — UI test confirms.
- **Defensive state:** `GameView.swift:33-35` resets `zoomedIndex` on puzzle-id change; reduceMotion gating (`GameView.swift:132-138`) is correct.
- **No retain cycles:** all views are structs; closures capture by value; `onTap`/`onDismiss` are plain `let`.
- **NSCache reuse:** `PuzzleImage.load` hits cache on zoom → no re-decode.
- **a11y:** cell labels/hints + overlay combined label + explicit `.accessibilityAction(named:"Dismiss")` is good VoiceOver UX; `Color.clear` empty slot is correctly skipped by VoiceOver.
- **Style:** `.buttonStyle(.plain)`, `RoundedRectangle(cornerRadius:10)`, `.contentShape`, `.foregroundStyle` match the rest of the codebase.

## Recommended Actions (priority order)
1. **MAJOR-1:** Rewrite `plan.md` + both phase files to reflect grid-area-only scope; check off phase-02 todos. (Required before any future agent re-enters this plan.)
2. Optional: MINOR-3 (delete redundant `.combine`) — 1-line trivial cleanup.
3. Optional: MINOR-2 (shadow parity) — 1-line polish.
4. Optional: MINOR-6 (UI-test hit-testing assertion) — strengthens the regression that defines this refactor.
5. Defer MINOR-1/4/5 unless touching this area again.

## Metrics
- Type Coverage: N/A (SwiftUI views, no generics-heavy code)
- Test Coverage: 36/36 unit + 1 UI test (zoom in/out + hint-bar-visible); no new unit tests for this feature (none needed — pure UI)
- Linting Issues: 0 (build clean per trusted report)
- matchedGeometry runtime warnings: 0 expected (single-id-per-namespace verified by construction)

## Unresolved questions
- Is the credit-pill-during-hero behavior (MINOR-1) acceptable to product, or should it fade in post-zoom per the original phase-02 R10 intent? Needs product call before scheduling.
