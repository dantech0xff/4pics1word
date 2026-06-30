# Design Guidelines — 4 Pics 1 Word

UI/UX patterns established in code; mirror these in new views. Last updated: 2026-06-30.

## Iconography
SF Symbols throughout. Recurring glyphs:
- `bitcoinsign.circle.fill` — coins/reward (also `circle.fill` mini-glyph in counters).
- `gift.fill` — Day-7 jackpot.
- `checkmark.circle.fill` — claimed-day success (green).
- `lock.fill` — locked future tiles (desaturated, glassy chip).
- `calendar.badge.checkmark` — Home check-in toolbar button.
- `square.grid.2x2.fill` — app brand mark (splash + Home).
- `checkmark.seal.fill` — WinView success.
- `lightbulb` / `minus.circle` / `shuffle` — hint buttons.

## Color usage
- `.accentColor` — primary interactive accent (claim buttons, today borders, locked-tile check, hint-button backgrounds).
- `.yellow` — coins/coin counters; jackpot gradient top.
- `.orange` — jackpot gradient bottom + JACKPOT pill.
- `.green` — success (solve glow, locked-hint slots, claimed check).
- `.red` — wrong-answer rejection (glow + shake, error haptic).
- `.secondary` — de-emphasis / metadata text.

## Sheets & presentation
- Daily check-in + WinView: `.presentationDetents([.medium])` + `.presentationDragIndicator(.visible)`.
- WinView: `.interactiveDismissDisabled(true)` (must pick Next/Home).
- Check-in sheet: `.interactiveDismissDisabled(model.canCheckInToday)` (gate pre-claim).
- Game = `fullScreenCover`; zoom = in-grid overlay (not fullscreen).

## Materials & background
- `.background(.ultraThinMaterial)` for translucent chips (lock chips, sheet backing) — gated off when `accessibilityReduceTransparency`.
- Solid `Color(.systemBackground)` fallback when transparency reduced.

## Typography & layout
- `@ScaledMetric` for tile sizing (e.g. `cellHeight = 96`, `corner = 18`) → respects Dynamic Type.
- `.monospacedDigit()` on all coin/score counters (no jitter on tick).
- `.contentTransition(.numericText())` for animated counter increments.
- Dynamic Type capped at `.accessibility2` on tiles (`dynamicTypeSize(...DynamicTypeSize.accessibility2)`).

## Animation
- `TimelineView(.animation)` for continuous fx (today-cell diagonal shimmer sweep, 2.5s loop).
- `TimelineView(.periodic(by: 1))` for live countdowns (auto-cancels on dismiss — no `Timer.publish` wiring).
- `KeyframeAnimator` for per-tile solve-wave (scale + rotation + glow, L→R stagger via leading idle keyframe) and wrong-rejection (red glow + horizontal shake, no stagger).
- `.animation(.snappy, value:)` for bank/slot reflow.
- `.spring(response:dampingFraction:)` for coin-fly and image-zoom transitions.

## Reward flourishes
- **Coin-fly:** `bitcoinsign.circle.fill` springs from today-cell to header counter via captured frames (named coordinate space + `PreferenceKey`); counter ticks via `.numericText()` as coin arrives.
- **Confetti:** Day-7 jackpot only (`ConfettiOverlay`, 36 particles, 6-color, Canvas-drawn).
- **Pulse:** today-cell `scaleEffect(1.08)` on claim.

## Accessibility gates (mandatory)
- `accessibilityReduceMotion` → skip all decorative animation (wave, shake, shimmer, confetti, coin-fly); functional state changes still apply.
- `accessibilityReduceTransparency` → swap `.ultraThinMaterial` → solid fills.
- `dynamicTypeSize.isAccessibilitySize` → fall back to simpler layouts (e.g. jackpot tile vertical instead of horizontal).
- Every interactive element has `accessibilityIdentifier` (UI tests) + spoken `accessibilityLabel` (VoiceOver).
- Countdown VoiceOver reads spoken words ("in N hours M minutes"), not raw `HH:MM:SS`.

## Haptics
- `Feedback.tap()` on every tile/button tap; `.wrong()` on bad submit; `.win()`/`.celebrationChime()` on solve; `.reward()` on check-in claim; `.warning()` on blocked dismiss.
- All gated by `Feedback.enabled` (mirrors Settings); cached generators warmed via `prepareCelebration()`.
- No audio assets shipped (system sound IDs are undocumented/ unstable across iOS).
