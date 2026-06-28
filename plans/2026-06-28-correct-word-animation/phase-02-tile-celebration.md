# Phase 02 — Per-Tile Celebration Modifier (KeyframeAnimator)

## Context Links
- Research: `research/researcher-01-animation-report.md` §1,§2,§6
- Scout: `scout/scout-01-codebase-report.md` §1,§6
- Source: `4pics1word/Components/AnswerSlots.swift`

## Overview
- Priority: P2. Status: Pending. Deps: Phase 01 (`solvedToken`).
- Build the visual wave: per-tile `KeyframeAnimator` (scale+rotate+green-glow), staggered L→R by leading idle keyframe (`index·0.08s`). Reuse locked-tile green. Gate via `accessibilityReduceMotion`. Fix `ForEach` key `\.offset` → `tile.id`.

## Key Insights
- `KeyframeAnimator(initialValue:repeatCount:1,trigger:)` (iOS18+) = independent curves per property ⇒ ideal for celebration (scale/rotate/glow desync naturally). `repeatCount:1` ⇒ one-shot, ends on neutral keyframes ⇒ **no reset needed**.
- **Stagger-as-leading-keyframe trick:** single shared `@State celebrate` trigger; per-tile leading `CubicKeyframe(neutral, duration: index·0.08)` delays that tile's wave without per-tile timers/dicts. DRY + KISS.
- `ForEach` keyed by `\.offset` (AnswerSlots L9) rebuilds row on identity churn ⇒ kills animation. **Must change to `tile.id`** BEFORE shipping wave. Flag from researcher §6.
- `.shadow` (GPU-cheap) > `.blur` (fullscreen pass). Wrap each tile in `.compositingGroup()` before shadow to halve overdraw.
- Keep `.animation(.snappy, value: state.slotTile.map { $0?.id })` (L17) — different system, won't fight keyframes.
- Final keyframes are all neutral ⇒ tiles return to idle post-wave. Locked-tile green styling persists underneath (tile.locked unchanged).

## Requirements
- **R1** Wave plays once on `celebrate` toggle, L→R, all tiles.
- **R2** Per tile: scale 1→1.15→1; rotation 0→-8°→+8°→0°; green glow 0→1→0 (shadow `color:.green.opacity(0.9·glow)`, `radius:12·glow`).
- **R3** Stagger `0.08s`/tile via leading idle keyframe; active ≈ `0.40s`/tile.
- **R4** `accessibilityReduceMotion` ⇒ skip keyframes entirely (jump to final green state, no transform).
- **R5** `ForEach` keyed by `tile.id` (nil-safe wrapper for empty slots).
- **R6** Locked (hint) tiles animate too (unified rhythm — see plan Q5; default YES).
- **R7** No blur. `.compositingGroup()` before shadow on each tile.
- **N1** No layout shift: transforms are purely visual (scale/rotation/shadow); frame/background/stroke sizes unchanged.

## Architecture
```
AnswerSlots
  @State celebrate: Bool = false
  @State solvedVersion: Int = 0          // tracks last-seen solvedToken
  .onChange(of: state.solvedToken) { celebrate.toggle() }   // single trigger source
  HStack → ForEach(id: tile?.id ?? "empty\(offset)") { offset, tile in
      if let tile { slotTile(tile, index: offset, celebrate: celebrate, reduceMotion: reduceMotion) }
      else { emptySlot }
  }
slotTile:
  Text(...)
    .scaleEffect(v.scale).rotationEffect(v.angle)
    .shadow(color:.green.opacity(0.9*v.glow), radius:12*v.glow, y:2)
    .compositingGroup()
    .keyframeAnimator(initialValue: TileFX(), trigger: celebrate, repeatCount:1) { c,v in c } keyframes: { _ in
        let d = Double(index)*0.08
        KeyframeTrack(\.scale){ CubicKeyframe(1,d); CubicKeyframe(1.15,0.12); CubicKeyframe(1,0.14) }
        KeyframeTrack(\.angle){ CubicKeyframe(.zero,d); CubicKeyframe(.degrees(-8),0.08); CubicKeyframe(.degrees(8),0.10); CubicKeyframe(.zero,0.08) }
        KeyframeTrack(\.glow){ CubicKeyframe(0,d); CubicKeyframe(1,0.12); CubicKeyframe(0,0.22) }
    }
```
`TileFX { var scale:CGFloat=1; var angle:Angle=.zero; var glow:CGFloat=0 }` — private struct in AnswerSlots file (no `_` prefix; only entrypoint needs it).

## Related Code Files
- **MODIFY** `4pics1word/Components/AnswerSlots.swift`
  - L4 struct: add `@State private var celebrate = false`, `@Environment(\.accessibilityReduceMotion) private var reduceMotion`.
  - L9 `ForEach`: change `id: \.offset` → `id: \.offset` REPLACED by stable id. Since elements are `Tile?`, use `id: KeyPath` on a wrapper OR map to identifiable. Simplest: `ForEach(Array(state.slotTile.enumerated()), id: \.element?.id ?? .offset)` won't typecheck; use `id: \.offset` is the bug. **Fix:** iterate `(0..<slotCount)` with explicit `id:` — `ForEach(0..<state.slotCount, id:\.self)` then read `state.slotTile[i]`. Stable per-position identity, avoids `\.offset` rebuild semantics. (Researcher's `tile.id` recommendation adapted for optional slots.)
  - L9 closure: pass `index` + `celebrate` + `reduceMotion` into `slotTile`.
  - L28 `slotTile(_:)` → `slotTile(_ tile: Tile, index: Int, celebrate: Bool, reduceMotion: Bool)`: apply scale/rotation/shadow conditionally (guard `celebrate && !reduceMotion`) + keyframeAnimator; on reduceMotion keep plain green tile.
  - L17 `.animation(.snappy...)`: keep.
  - Add `.onChange(of: state.solvedToken) { _, _ in celebrate.toggle() }` on HStack.
  - Add `private struct TileFX { ... }` at file bottom.

## Implementation Steps
1. Add `TileFX` struct (scale/angle/glow) at bottom of `AnswerSlots.swift`.
2. Add `@State celebrate` + `reduceMotion` env to `AnswerSlots`.
3. Rewrite `ForEach` to `(0..<state.slotCount, id:\.self)`; pass index.
4. Extend `slotTile` signature with `index`, `celebrate`, `reduceMotion`.
5. In `slotTile`: wrap `Text` with `.scaleEffect/.rotationEffect/.shadow(.green...)/.compositingGroup()` guarded by `celebrate && !reduceMotion`.
6. Attach `.keyframeAnimator(initialValue:TileFX(), trigger:celebrate, repeatCount:1){ c,v in c } keyframes:{...}` (stagger `d=index·0.08`).
7. Add `.onChange(of: state.solvedToken){ celebrate.toggle() }`.
8. Build + Preview in Xcode (simulate solve by toggling `celebrate`).

## Todo List
- [ ] `TileFX` struct added
- [ ] `@State celebrate` + `reduceMotion` env wired
- [ ] `ForEach` re-keyed to `id:\.self` over `(0..<slotCount)`
- [ ] `slotTile` applies scale/rotate/shadow + keyframeAnimator
- [ ] reduceMotion branch skips animation
- [ ] `.onChange(solvedToken)` toggles celebrate
- [ ] Build green; visual verify in Simulator (force-toggle)

## Success Criteria
- Toggling `celebrate` ⇒ visible L→R wave (scale+rotate+green-glow) on all filled tiles.
- `reduceMotion=true` ⇒ no transform, instant green.
- No full-row rebuild during wave (verify no flicker).
- Wave self-resolves to neutral (final keyframes) ⇒ no manual reset.
- `.animation(.snappy)` slot-fill still works for normal place/remove.

## Risk Assessment
- **R-Flicker (MED):** `ForEach` re-key could itself cause one rebuild on first solve. Mitigation: re-key done in this phase, verified before wave shipped.
- **R-RepeatOnRerender (LOW):** `keyframeAnimator(trigger:)` replays only when `celebrate` changes value, not on every render. Safe.
- **R-StuckMidFrame (LOW):** navigating away mid-wave leaves tile mid-keyframe. Mitigation: final keyframes are neutral; `.onDisappear` cancels driver (Phase 04). Add `.id(celebrate)` ONLY if observed stuck.

## Security Considerations
- None. Pure view layer.

## Next Steps
- → Phase 03 (haptics, parallel) + Phase 04 (wave driver consumes `solvedToken`).
