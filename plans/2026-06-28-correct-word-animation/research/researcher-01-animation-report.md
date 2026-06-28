# Research: Correct-Word Celebration Wave (SwiftUI, iOS 17+/26)

Scope: animate the `AnswerSlots` row (`HStack` + `ForEach enumerated`, `Tile.locked`) left→right when the word is correct. One-shot, non-looping, multi-property per tile (scale + rotation + glow), then fire bottom sheet.

## 1. Sequential stagger (ripple) — recommend `.delay()` baked into keyframes via single trigger

| Approach | Verdict |
|---|---|
| `Timer.publish` driving `@State index` | ❌ Couples to run loop, leaky, manual invalidate. Skip. |
| `Task.sleep` driving per-tile `trigger[id]` dict | OK, flexible, gives completion in same task. More state. |
| `withAnimation { }` + `Animation.linear(delay: idx*0.08)` per tile | Only 1 transition value; can't do mid keyframe (1→1.15→1). Weak for celebration. |
| **`keyframeAnimator(repeatCount:1, trigger:)` + leading idle keyframe `duration: idx*0.08`** | ✅ **RECOMMENDED.** Single trigger, no per-tile dict, stagger expressed in keyframes, multi-stage native. |

**Why:** 2025 SwiftUI = declarative, value-driven, structurally safe. The leading-idle keyframe trick (a `CubicKeyframe` holding the neutral value for `index*0.08s` before the active frames) makes one shared `@State celebrate` trigger produce a perfect left→right wave. No timers, no dictionary churn, no race.

## 2. Combined transform per tile — `KeyframeAnimator` (primary)

`KeyframeAnimator` is the only primitive that animates **independent properties on independent curves simultaneously** (scale and glow and rotation naturally desync) — exactly the celebration case. `PhaseAnimator` animates a single shared phase for all properties. Classic `withAnimation` can't hit a mid-point keyframe.

```swift
struct TileFX { var scale: CGFloat = 1; var angle: Angle = .zero; var glow: CGFloat = 0 }

// inside slotTile(_:), index from ForEach(...enumerated())
Text(String(tile.character))
    .scaleEffect(v.scale)
    .rotationEffect(v.angle)
    .shadow(color: .green.opacity(0.9 * v.glow), radius: 12 * v.glow, y: 2)
    .keyframeAnimator(initialValue: TileFX(), trigger: celebrate, repeatCount: 1) { c, v in c } keyframes: { _ in
        let d = Double(index) * 0.08            // stagger baked in
        KeyframeTrack(\.scale) {
            CubicKeyframe(1,    duration: d)
            CubicKeyframe(1.15, duration: 0.12)
            CubicKeyframe(1,    duration: 0.14)
        }
        KeyframeTrack(\.angle) {
            CubicKeyframe(.zero,        duration: d)
            CubicKeyframe(.degrees(-8), duration: 0.08)
            CubicKeyframe(.degrees(8),  duration: 0.10)
            CubicKeyframe(.zero,        duration: 0.08)
        }
        KeyframeTrack(\.glow) {
            CubicKeyframe(0, duration: d)
            CubicKeyframe(1, duration: 0.12)
            CubicKeyframe(0, duration: 0.22)
        }
    }
```

`repeatCount: 1` ⇒ plays once per trigger change and stops on the last keyframe (all neutral values ⇒ returns to idle, **no reset needed**). Re-celebrate ⇒ toggle `celebrate` again.

## 3. Completion — recommend stored `Task.sleep` (not `withAnimation(completion:)`)

| Approach | Verdict |
|---|---|
| `withAnimation(_:completion:)` (iOS 17+) | Fires after animations queued **inside its body** finish. KeyframeAnimator runs independently of `withAnimation` ⇒ completion fires immediately/never. Useless here. |
| **`Task { try? await Task.sleep(for: .seconds(total)) }`** stored in `@State` | ✅ **RECOMMENDED.** `total = (n-1)*stagger + perTile`. Cancellable, version-agnostic, colocated with trigger. |

```swift
@State private var celebrate = false
@State private var wave: Task<Void, Never>?

func celebrateWin(tileCount: Int, stagger: Double = 0.08, per: Double = 0.40) {
    wave?.cancel()                       // re-trigger safe
    celebrate.toggle()
    let total = Double(max(tileCount - 1, 0)) * stagger + per
    wave = Task {
        try? await Task.sleep(for: .seconds(total))
        guard !Task.isCancelled else { return }
        showWinSheet = true
    }
}
.onDisappear { wave?.cancel() }          // navigation safe
```

## 4. PhaseAnimator vs KeyframeAnimator vs withAnimation

| Tool | Avail | Multi-prop independent curves | One-shot | Verdict |
|---|---|---|---|---|
| `withAnimation` + `.animation(.delay(), value:)` | iOS 13/15 | ❌ | partial | Simple slides only. Can't do up→down. |
| `PhaseAnimator(phases:trigger:)` | iOS 17 | ❌ (shared phase) | ✅ via `trigger:` | Good for 2–3 discrete states, single property set. |
| **`keyframeAnimator(initialValue:repeatCount:trigger:)`** | base iOS 17; `repeatCount/trigger` **iOS 18+** | ✅ | ✅ `repeatCount:1` | **Best for this.** Target is iOS 26.5 ⇒ safe. |

## 5. Cancellation / re-trigger safety

- **Store the `Task`** in `@State`; `.cancel()` before each re-trigger and in `.onDisappear`. Guard `Task.isCancelled` before side effects (sheet).
- `keyframeAnimator(trigger:)` is **idempotent on toggle** — re-firing just replays; safe to spam.
- After a cancel, `keyframeAnimator` may leave a tile mid-frame if you navigate away mid-wave ⇒ wrap row in `.id(celebrate)` **only if** you observe stuck state; usually unnecessary because final keyframes are neutral.
- Use `.transaction { $0.animation = nil }` locally to stop inherited `.snappy` (already on `AnswerSlots`) from fighting the keyframes on unrelated `slotTile` changes. **Recommended:** keep `.animation(.snappy, value:)` for slot fill but it won't interfere with `keyframeAnimator` (different systems).

## 6. Performance

- **`.shadow(color:radius:)` > `.blur()`** — shadow is GPU-cheap; blur is a fullscreen pass. Avoid blur on N tiles. The `glow` track uses shadow only ⇒ fine for ≤12 tiles.
- Wrap each tile in **`.compositingGroup()`** before shadow/blend so children flatten to one layer, halving overdraw.
- For the **whole row**, consider `.drawingGroup()` (rasterizes to Metal) — fastest, but disables some live effects. Test; only add if profiling shows jank. YAGNI: skip until measured.
- Use stable `id:` (tile id, not `\.offset`) so SwiftUI animates properties, not identity — avoids full row rebuild. Current `AnswerSlots` keys `ForEach` by `\.offset` ⇒ **flag: change to `tile.id`** before shipping animation to avoid re-renders during the wave.

## Bottom line

Primary stack: **`keyframeAnimator(initialValue:repeatCount:1, trigger:)` per tile, stagger baked as leading idle keyframe, single `@State celebrate` trigger, completion via cancellable stored `Task.sleep`, guard `isCancelled`, `.onDisappear { wave?.cancel() }`.** Honors YAGNI (one trigger, no Timer/dict), KISS (declarative), DRY (one `TileFX` struct + keyframe builder reused per tile).

## References
- KeyframeAnimator: https://developer.apple.com/documentation/swiftui/keyframeanimator
- PhaseAnimator: https://developer.apple.com/documentation/swiftui/phaseanimator
- withAnimation(completion:): https://developer.apple.com/documentation/swiftui/withanimation(_:completion:)
- Animating keyframes (WWDC23): https://developer.apple.com/videos/play/wwdc2023/10157/

## Open questions
- Exact word length range (drives `total` for sheet timing). Confirm max tiles.
- Should tiles stay "lit" (green) after the wave, or revert? Current `locked=true` persists ⇒ recommend keep `locked` styling, animation purely transient over it.
