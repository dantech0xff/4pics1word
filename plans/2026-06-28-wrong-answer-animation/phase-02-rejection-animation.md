# Phase 02 — Per-Tile Rejection Animation (Red Glow + Shake)

## Context Links
- Research (animation): `research/researcher-01-animation-report.md` §1, §2, §3, §5, §6, §7
- Scout: `scout/scout-01-codebase-report.md` §3, §4
- Mirror template (FORMAT): `../2026-06-28-correct-word-animation/phase-02-tile-celebration.md`
- Source: `4pics1word/Components/AnswerSlots.swift`

## Overview
- Priority: P2. Status: Pending. Deps: Phase 01 (tiles stay populated during animation via deferred clear).
- Add `WrongFX: VectorArithmetic` (mirror of `TileFX`). Per-tile `keyframeAnimator(initialValue: WrongFX(), trigger: reject)` runs SIMULTANEOUSLY on all tiles (no stagger — error urgency). Red shadow + horizontal shake. `@State reject` toggles on `onChange(of: state.wrongAttemptToken)`. Reduce-motion branch renders plain `base`.

## Key Insights
- **No stagger** (unlike celebration's `index·0.08s` L→R wave): wrong is urgent/simultaneous; all tiles share identical keyframes.
- **Neutral final keyframes** (`glow:0`, `shakeX:0`) ⇒ no manual reset; rapid re-trigger from near-neutral has no visible discontinuity (same property celebration relies on, researcher-01 §7).
- **Red shadow > red `colorMultiply`:** `colorMultiply` tints the glyph red (illegible); `.shadow(color:.red.opacity(0.85·glow), radius:14·glow, y:2)` keeps glyph untouched. `.compositingGroup()` already on `base` (L51) renders shadow once around tile silhouette.
- **`.red` system hue** is iOS's semantic error/danger color — matches `Feedback.wrong()`'s `.error` haptic intent. Opacity `0.85` (vs celebration's `0.9`) keeps full-sat red readable over light/dark tiles. Radius `14` (vs `12`) sells alarm.
- **iOS-26 deviation (already hit by celebration):** `keyframeAnimator(initialValue:trigger:)` has **no `repeatCount:` param** — don't pass one.
- **`wrongAttemptToken` already observed** (no new token). `reject.toggle()` re-fires the animator on every wrong attempt (Bool flip suffices; SwiftUI keyframes re-run on any trigger value change).
- **Two animators coexist on one tile:** existing `celebrate` animator + new `reject` animator are independent (different triggers, different `initialValue` structs). No conflict — both wrap `base` and read neutral unless their trigger fires.
- **Reduce-motion contract:** decorative FX skipped (no keyframeAnimator); tile clear still happens in PuzzleState (functional, phase 01 + 03). Matches Apple HIG: reduce-motion users still receive info, lose only the movement.

## Requirements
- **R1** `WrongFX: VectorArithmetic` private struct with `glow: CGFloat` + `shakeX: CGFloat` (both `Double`-backed); full `+`/`-`/`+=`/`-=`/`scale`/`magnitudeSquared`/`zero`.
- **R2** `@State private var reject: Bool = false` in `AnswerSlots`; `.onChange(of: state.wrongAttemptToken)` toggles it.
- **R3** Per-tile `keyframeAnimator(initialValue: WrongFX(), trigger: reject)` applied inside `slotTile(_:index:)` (celebration animator stays). Reduce-motion branch unchanged (plain `base`).
- **R4** Glow track: `0.0(0.00)→1.0(0.08)→1.0(0.10)→0.0(0.12)` (total 0.30s).
- **R5** Shake track: `0(0.00)→-10(0.05)→8(0.06)→-5(0.07)→3(0.07)→-1.5(0.06)→0(0.05)` (total 0.36s). Decaying oscillation.
- **R6** Apply site: `content.offset(x: fx.shakeX).shadow(color: Color.red.opacity(0.85 * fx.glow), radius: 14 * fx.glow, y: 2)`.
- **R7** Tracks run parallel; animation ends at `max(0.30, 0.36)` ≈ 0.36s (GameView pads clear to 550ms — phase 03).
- **N1** No `repeatCount:` param. No `index`-based stagger in keyframes. No glyph tint (`.colorMultiply` forbidden).
- **N2** Celebration animator + `TileFX` untouched.

## Architecture
```swift
// AnswerSlots state (add next to celebrate, L9):
@State private var reject: Bool = false

// onChange wiring (add after the solvedToken onChange, ~L25):
.onChange(of: state.wrongAttemptToken) { _, _ in
    reject.toggle()
}

// Per-tile wrap inside slotTile(_:index:), AFTER the celebration if/else,
// so both animators compose. Reduce-motion already short-circuits above.
if reduceMotion {
    base
} else {
    base
        .keyframeAnimator(initialValue: WrongFX(), trigger: reject) { content, fx in
            content
                .offset(x: fx.shakeX)
                .shadow(color: Color.red.opacity(0.85 * fx.glow),
                        radius: 14 * fx.glow, y: 2)
        } keyframes: { _ in
            KeyframeTrack(\.glow) {
                CubicKeyframe(0.0, duration: 0.00)
                CubicKeyframe(1.0, duration: 0.08)
                CubicKeyframe(1.0, duration: 0.10)
                CubicKeyframe(0.0, duration: 0.12)
            }
            KeyframeTrack(\.shakeX) {
                CubicKeyframe(0.0,   duration: 0.00)
                CubicKeyframe(-10,   duration: 0.05)
                CubicKeyframe(8,     duration: 0.06)
                CubicKeyframe(-5,    duration: 0.07)
                CubicKeyframe(3,     duration: 0.07)
                CubicKeyframe(-1.5,  duration: 0.06)
                CubicKeyframe(0,     duration: 0.05)
            }
        }
}

// New struct at file bottom (mirror TileFX at L98):
private struct WrongFX: VectorArithmetic {
    var glow: CGFloat = 0.0
    var shakeX: CGFloat = 0.0

    var magnitudeSquared: Double {
        Double(glow) * Double(glow) + Double(shakeX) * Double(shakeX)
    }
    mutating func scale(by factor: Double) {
        glow *= factor
        shakeX *= factor
    }
    static var zero: WrongFX { WrongFX() }
    static func +(lhs: WrongFX, rhs: WrongFX) -> WrongFX {
        WrongFX(glow: lhs.glow + rhs.glow, shakeX: lhs.shakeX + rhs.shakeX)
    }
    static func -(lhs: WrongFX, rhs: WrongFX) -> WrongFX {
        WrongFX(glow: lhs.glow - rhs.glow, shakeX: lhs.shakeX - rhs.shakeX)
    }
    static func +=(lhs: inout WrongFX, rhs: WrongFX) { lhs = lhs + rhs }
    static func -=(lhs: inout WrongFX, rhs: WrongFX) { lhs = lhs - rhs }
}
```

## Related Code Files
- **MODIFY** `4pics1word/Components/AnswerSlots.swift`
  - L9: add `@State private var reject: Bool = false` under `celebrate`.
  - L25 (after the `solvedToken` onChange): add `.onChange(of: state.wrongAttemptToken) { _, _ in reject.toggle() }`.
  - L36-92 (`slotTile(_:index:)`): wrap the existing non-reduceMotion branch in the additional `.keyframeAnimator(initialValue: WrongFX(), trigger: reject) { … } keyframes: { … }` (compose on top of the celebration animator — both read neutral unless their trigger fires).
  - After L127 (file bottom): add `private struct WrongFX: VectorArithmetic { … }`.

## Implementation Steps
1. Add `private struct WrongFX: VectorArithmetic` at file bottom (copy researcher-01 §1 verbatim).
2. Add `@State private var reject: Bool = false` under `celebrate` (L9).
3. Add `.onChange(of: state.wrongAttemptToken) { _, _ in reject.toggle() }` after L25.
4. In `slotTile(_:index:)` non-reduceMotion branch (L60-91), wrap the existing celebration-animator result in a second `.keyframeAnimator(initialValue: WrongFX(), trigger: reject)` with R4/R5 keyframes and R6 apply site.
5. Build green.
6. Preview: temporarily `reject = true` to verify red glow + shake render; revert.
7. Manual: with phase 01 + 03 landed, wrong submit shows glow+shake before clear.

## Todo List
- [ ] `WrongFX` struct added at file bottom
- [ ] `@State reject` added
- [ ] `.onChange(wrongAttemptToken)` toggles reject
- [ ] Per-tile rejection keyframeAnimator composed onto `slotTile`
- [ ] Reduce-motion branch still returns plain `base`
- [ ] Build succeeds
- [ ] Visual verify (force-toggle `reject` in preview)

## Success Criteria
- Wrong submit (with phase 01 + 03 landed) ⇒ all slotted tiles glow red + shake simultaneously.
- Reduce-motion ⇒ no glow, no shake (clear still happens via PuzzleState).
- Rapid re-trigger (spam wrong submits) ⇒ no visible discontinuity (neutral final keyframes).
- Celebration animator still fires on solve; both animators coexist without conflict.
- No glyph tinting (glyph stays `.primary` / `.green` for locked).

## Risk Assessment
- **R-TwoAnimatorsCompose (LOW):** stacking two `keyframeAnimator` modifiers on one tile is supported (each is an independent wrapper). Celebration uses one; this adds a second. Verify no transform leak when only one trigger fires.
- **R-RapidRetrigger (LOW):** keyframeAnimator restarts from current animated value on trigger flip. Mitigated by neutral final keyframes (researcher-01 §7). No manual reset needed.
- **R-ClearRace (MED):** if GameView's clear fires before ~0.36s elapses, tiles vanish mid-shake. Mitigated by phase 03's 550ms sleep > 0.36s animation. Confirmed in plan timing budget.
- **R-KeyframeCount (LOW):** 2 tracks × 4–7 keyframes × up to 7 tiles = trivial per-frame cost.

## Security Considerations
- None. Pure view layer.

## Next Steps
- → Phase 03 (parallel): GameView `wrongTask` driver + remove `triggerShake`/`shakeOffset`.
- → Phase 04 (after all): Swift Testing `PuzzleStateWrongAttemptTests`.
