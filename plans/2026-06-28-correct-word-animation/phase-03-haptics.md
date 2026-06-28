# Phase 03 — Haptics (Per-Tile Light + Final Chime + prepare())

## Context Links
- Research: `research/researcher-02-haptics-sheet-report.md` TOPIC A (A1–A5)
- Source: `4pics1word/Game/Feedback.swift`, `4pics1word/Views/WinView.swift`

## Overview
- Priority: P2. Status: Pending. Deps: Phase 01 (celebration window exists).
- Extend `Feedback` with cached generators + `celebrationTap(intensity:)` (per-tile `.light` impact) + `celebrationChime()` (`.success` notification) + `prepareCelebration()` (warm hardware ~100ms pre-burst). All gated on `Feedback.enabled`. iPhone-only; silent iPad/Simulator (no-op, expected).

## Key Insights
- `UIImpactFeedbackGenerator(.light)` best for per-tile taps (5 styles + 0.0–1.0 intensity). `UINotificationFeedbackGenerator().notificationOccurred(.success)` for final chime. **No CoreHaptics** (YAGNI). [research A1]
- `prepare()` is REQUIRED for low latency — hardware sleeps after ~1–2s idle; first cold `impactOccurred` adds tens-of-ms lag. Call before burst. Idempotent + cheap. [research A2]
- `prepare()` only helps if SAME generator instance reused ⇒ `Feedback` must cache generators (currently creates fresh each call). Minor refactor.
- `UI*FeedbackGenerator` is safe from `@MainActor` (project default). `Task.sleep(for:)` loop is the stagger driver. [research A3]
- No `AVAudioSession` needed (pure UIKit haptics). No permission/Info.plist. System "Sounds & Haptics" toggle auto-gates. [research A4, A5]
- Simulator is silent — haptic verify is DEVICE-ONLY. Document in Phase 05.

## Requirements
- **R1** `Feedback` holds `static let` cached `UIImpactFeedbackGenerator(.light)` + `UINotificationFeedbackGenerator` (so `prepare()` is meaningful).
- **R2** `celebrationTap(intensity:)` fires `.light` impact at `intensity` (0.0–1.0); respects `enabled`.
- **R3** `celebrationChime()` fires `.success`; respects `enabled`.
- **R4** `prepareCelebration()` calls `prepare()` on both cached generators; respects nothing (always warms — cheap).
- **R5** Existing `tap()/wrong()/win()` UNCHANGED in behavior (may route to cached generators for consistency — optional; keep diff minimal: leave as-is to avoid touching LetterBank/GameView behavior).
- **R6** `Feedback.enabled` gate preserved on every fire method.

## Architecture
```
enum Feedback {
  static var enabled = true
  private static let lightGen = UIImpactFeedbackGenerator(style: .light)     // cached
  private static let notifyGen = UINotificationFeedbackGenerator()           // cached
  // existing tap()/wrong()/win() — UNCHANGED (fresh generators; not worth unifying → minimal diff)
  static func celebrationTap(intensity: CGFloat = 0.7) { guard enabled else {return}; lightGen.impactOccurred(intensity: intensity) }
  static func celebrationChime() { guard enabled else {return}; notifyGen.notificationOccurred(.success) }
  static func prepareCelebration() { lightGen.prepare(); notifyGen.prepare() }
}
```
Driver loop (Phase 04 owns the `Task`):
```
Feedback.prepareCelebration()
for i in 0..<n { guard !Task.isCancelled else {return}; Feedback.celebrationTap(intensity: 0.5 + 0.1*CGFloat(i)/CGFloat(max(n-1,1))); try? await sleep(0.08s) }
guard !Task.isCancelled else {return}
Feedback.celebrationChime()   // final success — replaces WinView.onAppear win()
```
Intensity ramps 0.5→0.6 across tiles (subtle crescendo; trivial, design-call from research open-Q). Keep flat 0.7 if simpler — default flat per KISS.

## Related Code Files
- **MODIFY** `4pics1word/Game/Feedback.swift`
  - Add `private static let lightGen`, `private static let notifyGen`.
  - Add `celebrationTap(intensity:)`, `celebrationChime()`, `prepareCelebration()` (each with `guard enabled`).
  - Leave `tap()/wrong()/win()` bodies as-is (minimal diff).

## Implementation Steps
1. Add two `private static let` cached generators to `Feedback`.
2. Add `celebrationTap(intensity: CGFloat = 0.7)` → `lightGen.impactOccurred(intensity:)`.
3. Add `celebrationChime()` → `notifyGen.notificationOccurred(.success)`.
4. Add `prepareCelebration()` → both `.prepare()`.
5. Build.

## Todo List
- [ ] cached generators added
- [ ] `celebrationTap(intensity:)` added (enabled-gated)
- [ ] `celebrationChime()` added (enabled-gated)
- [ ] `prepareCelebration()` added
- [ ] existing tap/wrong/win untouched
- [ ] Build green

## Success Criteria
- `Feedback.celebrationTap()` / `celebrationChime()` callable; no-op when `enabled=false`.
- `Feedback.prepareCelebration()` callable, no throw.
- `tap()/wrong()/win()` behavior identical (LetterBank shake-tap, wrong-shake, etc. unchanged).
- **Device test (iPhone 7+):** perceptible per-tile tap + final chime. Simulator: silent (expected).

## Risk Assessment
- **R-Silent (LOW):** iPad/Simulator silent — expected, not a bug. Phase 05 QA notes device requirement.
- **R-SettingsGate (LOW):** system "System Haptics" off ⇒ auto-silent; `Feedback.enabled=false` mirrors app setting. Double-gate fine.
- **R-Latency (MED):** cold first-tap laggy without `prepare()`. Mitigated by `prepareCelebration()` called at wave start (Phase 04).

## Security Considerations
- None. No permission, no PII.

## Next Steps
- → Phase 04 wires `prepareCelebration()` + tap-loop + `celebrationChime()` into the wave Task.
