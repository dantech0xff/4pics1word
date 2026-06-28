# Researcher 01 — Wrong-Answer Rejection Animation (iOS 26 SwiftUI)

Scope: animation/visual technique ONLY. Mirrors `TileFX`/`KeyframeAnimator` in `AnswerSlots.swift:62-127`. No app code written.

## §1 KeyframeAnimator reuse — `WrongFX: VectorArithmetic`

Parallel to `TileFX` (`AnswerSlots.swift:98-127`). Two fields, both `Double`-backed CGFloat so `VectorArithmetic` is trivial (Apple's `CGFloat` conforms via its `Double` storage; this is exactly why `TileFX.glow` works today).

```swift
private struct WrongFX: VectorArithmetic {
    var glow: CGFloat = 0.0     // red shadow intensity 0→1→0
    var shakeX: CGFloat = 0.0   // horizontal oscillation offset (points)

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
Confirmed: 2-field struct mirrors proven `TileFX`; `CGFloat` fields satisfy conformance. No `scale`/`angleRad` — wrong state is pure glow+shake (no celebration pop).

## §2 Keyframe curves (glow + shake)

**No stagger** — error is urgent/simultaneous, unlike celebration's L→R wave (`index*0.08`). All tiles share identical keyframes. Total budget **0.55s** (snappier than 0.7-1.2s celebration).

```swift
KeyframeTrack(\.glow) {
    CubicKeyframe(0.0, duration: 0.00)   // neutral start
    CubicKeyframe(1.0, duration: 0.08)   // quick rise (urgency)
    CubicKeyframe(1.0, duration: 0.10)   // hold (~2 frames at 60fps)
    CubicKeyframe(0.0, duration: 0.12)   // fall
}                                         // glow total: 0.30s
KeyframeTrack(\.shakeX) {
    CubicKeyframe(0.0,  duration: 0.00)
    CubicKeyframe(-10,  duration: 0.05)  // jolt left
    CubicKeyframe(8,   duration: 0.06)   // decaying oscillation
    CubicKeyframe(-5,  duration: 0.07)
    CubicKeyframe(3,   duration: 0.07)
    CubicKeyframe(-1.5,duration: 0.06)
    CubicKeyframe(0,   duration: 0.05)   // settle
}                                         // shake total: 0.36s
```
Tracks run in parallel (SwiftUI semantics); animation ends at `max(0.30, 0.36)` ≈ **0.36s**, padded to ~0.55s by the clear-deferral. Decaying amplitudes (10→8→5→3→1.5→0) read as "rejection"; cubic interpolation gives spring-like snap without `spring` (keyframes are time-based, not physics). Final keyframes are neutral (glow 0, shakeX 0) ⇒ no manual reset (see §7).

## §3 Red shadow spec

Mirror celebration's shadow apply (`AnswerSlots.swift:69`). Use system `.red`:

```swift
.shadow(color: Color.red.opacity(0.85 * fx.glow),
        radius: 14 * fx.glow, y: 2)
```
- **`.red`** (system) not `.pink`/`.orange` — `.red` is the iOS semantic "error/danger" hue (matches `Feedback.wrong()`'s `.error` haptic intent); `.pink`/`.orange` read playful not urgent.
- Opacity `0.85` (vs celebration's `0.9`) — red at full sat is harsh; slight reduction keeps it readable over light/dark tiles.
- Radius `14` (vs `12`) — wider bloom sells "alarm"; glow holds at 1.0 for 0.10s so the radius is visible.
- **Keep `.compositingGroup()`** above the shadow (already on `base` at line 51). Shadow on a composited group renders once around the tile silhouette; without it, shadow would be per-subview (Text + background). `colorMultiply` overlay would tint the glyph red (wrong — glyph must stay legible); shadow keeps glyph untouched. **Shadow wins.**

## §4 Shake location — recommendation: **per-tile `shakeX` (option a)**

- (a) per-tile keyframe `shakeX` inside AnswerSlots — **RECOMMEND.** Row-only shake focuses attention on the wrong word; mirrors celebration's DRY self-contained AnswerSlots; co-located with glow so single trigger drives both; naturally reduce-motion-aware via same `if reduceMotion` branch.
- (b) existing GameView `shakeOffset` (`GameView.swift:13,30,150-156`) — shakes WHOLE view (pictures, header, bank). Diffuse, less focused; only 0.20s (4×0.05) — too short, reads as a twitch.
- **Action:** delete `triggerShake()` + `shakeOffset` + the shake call in `onChange(wrongAttemptToken)` (keep `Feedback.wrong()` there). Per-tile shake replaces it.

## §5 reduce-motion contract

Celebration skips the wave entirely (decorative). Wrong is different: **tile clear is functional** (must return to bank), only glow+shake is decorative.

Contract:
```swift
if reduceMotion {
    base   // no keyframeAnimator; tiles still cleared by PuzzleState
} else {
    base.keyframeAnimator(initialValue: WrongFX(), trigger: reject) { … } keyframes: { … }
}
```
Clearing happens in `PuzzleState.evaluate()` post-deferral regardless of motion setting — reduce-motion users still get the clear, just instant, no FX. Matches Apple guidance (HIG: "reduce-motion users still receive info, lose only the parallax/movement").

## §6 Trigger wiring

Mirror celebration's `@State celebrate: Bool` toggled on `onChange(of: state.solvedToken)` (`AnswerSlots.swift:9,23-25`):

```swift
@State private var reject: Bool = false
// …
.onChange(of: state.wrongAttemptToken) { _, _ in
    reject.toggle()
}
// per-tile:
.keyframeAnimator(initialValue: WrongFX(), trigger: reject) { content, fx in
    content
        .offset(x: fx.shakeX)
        .shadow(color: Color.red.opacity(0.85 * fx.glow),
                radius: 14 * fx.glow, y: 2)
} keyframes: { _ in
    // §2 tracks — NO `index`-based stagger
}
```
- iOS 26 trigger-variant `keyframeAnimator(initialValue:trigger:)` has **no `repeatCount` param** — celebration already deviated the same way (scout §6). Confirmed.
- `wrongAttemptToken` already exists (`PuzzleState.swift:32`) — no new token needed. `reject.toggle()` re-fires animator on every wrong attempt (Bool flip is enough; SwiftUI keyframes re-run on any trigger value change).
- **Clear must be deferred** until keyframes complete (~0.36s): that's engine work (scout §1/§5), out of scope here — animator just needs `slotTile[index]` still populated during animation. Engine change feeds this; report assumes deferral lands.

## §7 Risks

- **Rapid re-trigger:** user spams wrong submits. SwiftUI `keyframeAnimator(trigger:)` restarts from current animated value on each trigger flip — mid-animation re-trigger can cause a jump. Mitigation: final keyframes are neutral (`glow:0`, `shakeX:0`), so a re-trigger from near-neutral state has no visible discontinuity. **No manual reset needed.** Same property celebration relies on.
- **Clear-deferral race:** animator reads `slotTile[index]`; if engine clears before ~0.36s elapses, tiles vanish mid-shake. Engine must defer clear (scout §1). Out of scope for this report — flag to planner.
- **`KeyframeTrack` count:** 2 tracks × 6-7 keyframes is well within SwiftUI's per-frame cost; 7-tile row = 14 tracks, trivial.
- **`isRejecting` guard** (scout §5 option a) is orthogonal — gates input, not animation. Animation works regardless.

## Unresolved questions
- Exact clear-deferral mechanism (engine-side) — planner owns. Animation assumes tiles present for ≥0.36s post-token.
- Haptic during shake: keep single `Feedback.wrong()` at trigger, or add per-oscillation taps (celebration does per-tile taps)? Recommend single — error haptic should be one sharp pulse, not a rhythm.
