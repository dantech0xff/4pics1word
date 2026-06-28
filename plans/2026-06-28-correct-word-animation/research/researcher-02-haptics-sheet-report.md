# Researcher 02 — Haptics + Sheet Presentation

iOS 26 SwiftUI "4 pics 1 word" correct-word animation. Two topics: (A) haptic ripple synced to per-tile wave, (B) bottom sheet presented after the wave completes.

Refs: project uses `_pics1word` module, `@MainActor` default isolation, Swift Testing, iOS 26.5 deployment target. AGENTS.md.

---

## TOPIC A — Haptics synced to per-tile wave

### A1. API choice — recommendation: `UIImpactFeedbackGenerator`

| API | Control | Complexity | Fit |
|---|---|---|---|
| `UINotificationFeedbackGenerator().notificationOccurred(.success)` | 3 fixed types only | Lowest | Final chime only — useless for ripple (can't vary per tile, can't stagger meaningfully) |
| `UIImpactFeedbackGenerator(style:)` + `impactOccurred(intensity:)` | 5 styles + 0.0–1.0 intensity | Low | **Per-tile taps. Best fit.** |
| `CoreHaptics CHHapticEngine` | Full transient/continuous events, curves, time-precise | High (engine lifecycle, pattern dicts, `CHHapticPattern`) | Overkill. Only worth it if you later want audio-synced or waveform-shaped haptics |

**Recommendation:** `UIImpactFeedbackGenerator(style: .light)` for the per-tile ripple (N taps at ~80ms), then one `UINotificationFeedbackGenerator().notificationOccurred(.success)` for the final chime. KISS + YAGNI. Drop to CoreHaptics only if you outgrow it.
- https://developer.apple.com/documentation/uikit/uiimpactfeedbackgenerator
- https://developer.apple.com/documentation/uikit/uinotificationfeedbackgenerator
- https://developer.apple.com/documentation/corehaptics/chhapticengine

### A2. `prepare()` — required for low latency

Haptic hardware sleeps after ~1–2s idle; first `impactOccurred()` wakes it (adds ~tens of ms latency, feels laggy). Call `generator.prepare()` ~100–500ms before the expected burst.
- Best hook: when the round becomes winnable (last tile slot filled) or `onAppear` of the answer row. Re-call after any idle gap.
- `prepare()` is cheap; idempotent; safe to call every render cycle if needed.
- https://developer.apple.com/documentation/uikit/uifeedbackgenerator/2977615-prepare

### A3. Per-tile fire pattern — `Task` + `Task.sleep`

App is `@MainActor`-isolated by default (`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`). `UIImpactFeedbackGenerator` is `Sendable`-safe to use from `@MainActor`. Prefer structured concurrency over `DispatchQueue`:

```swift
@MainActor
func playRipple(count: Int) async {
    let tap = UIImpactFeedbackGenerator(style: .light)
    let chime = UINotificationFeedbackGenerator()
    tap.prepare(); chime.prepare()
    for _ in 0..<count {
        guard !Task.isCancelled else { return }
        tap.impactOccurred(intensity: 0.7)
        try? await Task.sleep(for: .milliseconds(80))
    }
    chime.notificationOccurred(.success)   // final chime
}
```
Stagger = ~80ms per tile. `Task.sleep(for:)` is iOS 16+. Keep the `Task` handle for cancellation (see B4). Drive the visual wave off the same loop (or pass `tileIndex` closure) so haptic + animation stay in lockstep — single source of truth beats two timers.

### A4. AVAudioSession — not required for UIKit FeedbackGenerator

UIKit `UI*FeedbackGenerator` plays haptics through the system haptic channel independent of `AVAudioSession`. **No `setCategory(.playback)` needed.** You only need an audio session config if (a) you use `CoreHaptics` with audio events, or (b) you also play sound effects and want them to mix correctly / override silent mode. For pure UIKit haptics: skip it.
- https://developer.apple.com/documentation/avfaudio/avaudiosession

### A5. Hardware / permission caveats

- **No permission required** — haptics need no entitlement or `Info.plist` key.
- **iPhone only with Taptic Engine** (iPhone 7+). **iPad has no Taptic Engine → silent.** iPhone SE (1st gen) also silent.
- **Simulator is silent** — `UIImpactFeedbackGenerator` etc. are no-ops on Simulator. Must test on real device. Add a `#if targetEnvironment(simulator)` note in QA.
- Respect **Settings → Sounds & Haptics → System Haptics** toggle — system gates automatically; nothing to do.

---

## TOPIC B — Bottom sheet after animation completes

### B1. Trigger pattern — `withAnimation(...) completion:` (iOS 17+)

Three options, ranked cleanest → least clean:
1. **`withAnimation(.easeOut(duration: 0.4)) { tilesLit = true } completion: { showSheet = true }`** — cleanest if the tile wave is a SwiftUI animation. The completion fires after the animation finishes; no manual duration math. (iOS 17+ `withAnimation` completion: https://developer.apple.com/documentation/swiftui/withanimation(_:completion:body:))
2. **`Task { try? await Task.sleep(for: .milliseconds(80 * tiles.count + 200)); showSheet = true }`** — required if the wave is `Task`-driven (e.g. the A3 loop). Just append a sleep + bool flip after the loop. Must guard cancellation (B4).
3. `DispatchQueue.main.asyncAfter` — avoid; doesn't cancel cleanly.

**Recommendation:** If tile wave is SwiftUI-animation-driven → option 1. If Task-driven (it is, per A3) → option 2, store the Task handle.

### B2. Sheet presentation — standard `.sheet` is enough

**No `.bottomSheet` modifier exists in iOS 26.** (The "Liquid Glass" release did not add one; the only sheet APIs are `.sheet` / `.fullScreenCover` / `.confirmationDialog`.)
- https://developer.apple.com/documentation/swiftui/view/sheet(ispresented:ondismiss:content:)

"Slide up over screen" feel:
- **`.sheet(isPresented: $showSheet)`** — slides up from bottom edge by default. Add:
  ```swift
  .presentationDetents([.medium, .large])
  .presentationDragIndicator(.visible)
  .presentationBackgroundInteraction(.enabled-up-through(.medium))  // let tiles stay tappable if desired
  ```
- **Custom `.overlay` + `.transition(.move(edge: .bottom))`** — only if you need full control (e.g. semi-transparent dim, non-modal, or to dodge `.sheet`'s view-capture behavior). More code; use only if `.sheet` feels wrong.

**Recommendation:** `.sheet`. It's the slide-up-over feel out of the box.

### B3. Sheet view-capture gotcha — not a problem here

Known SwiftUI issue: `.sheet` snapshots the presenting view's state at presentation time, so ongoing animations on the presenter can appear frozen inside the sheet's background or break. **Here it's safe**: the sheet is presented AFTER the tile wave completes, so tiles are already in their final lit state — no live animation is interrupted. **Just don't present the sheet mid-wave.** If you ever need to, switch to the `.overlay` + `.transition` approach (B2) which doesn't snapshot.

### B4. Cancellation guard — mandatory

If user dismisses / navigates / starts a new round during the delay window, the sheet must NOT pop up later.

```swift
@MainActor
final class GameModel {
    var rippleTask: Task<Void, Never>?

    func onCorrect() {
        rippleTask?.cancel()
        rippleTask = Task { @MainActor [weak self] in
            guard let self else { return }
            await playRipple(count: tiles.count)
            guard !Task.isCancelled, self.shouldPresentSheet else { return }   // double guard
            self.showSheet = true
        }
    }

    func dismiss() { rippleTask?.cancel(); showSheet = false }
}
```
Key points:
- Cancel the stored `Task` on dismiss / navigation / new round.
- Re-check `!Task.isCancelled` and a state flag (`shouldPresentSheet`) after the sleep — `cancel()` only sets the flag; a pending `sleep` won't throw until it wakes, and `try?` swallows it.
- For `withAnimation ... completion:` path: guard inside completion closure on the same state flag.

---

## TL;DR

- **Haptics:** `UIImpactFeedbackGenerator(.light)` per tile, `UINotificationFeedbackGenerator(.success)` for final chime. `prepare()` before the burst. `Task` + `Task.sleep(for: .milliseconds(80))` loop. No AVAudioSession needed. iPhone-only; silent on iPad/Simulator.
- **Sheet:** `withAnimation ... completion:` if SwiftUI-driven, else `Task` sleep + bool. Use `.sheet` + `presentationDetents`. Safe to present after animation finishes (no capture issue). Store & cancel the Task; re-guard post-sleep.

## Unresolved questions
- Final chime haptic: `.success` vs `.warning` tone — subjective, confirm with designer.
- Sheet detent height — confirm `.medium` vs custom fractional detent once the sheet UI mock exists.
- Should ripple `intensity` ramp (e.g. 0.5→1.0 across tiles) for "crescendo" feel? Trivial once A3 loop is in place; needs design call.
