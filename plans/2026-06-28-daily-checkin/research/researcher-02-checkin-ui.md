# Daily Check-in / Streak Reward — UX Research

Target: iOS 26.5, pure SwiftUI, no SPM. Codebase already ships `Feedback` (haptics) and `HomeView`.

## 1. Presentation pattern

**Recommendation: `.sheet` (medium detent), not `.fullScreenCover`.**

Apple HIG (Modality): prefer sheets over full-screen takeover unless the task is **focused, mandatory, and self-contained** (e.g., compose mail). A reward claim is a brief, optional moment — full-screen is overkill and breaks the player's flow. Sheets let the player see the game behind them, reinforce "I'm still in the game," and dismiss naturally on swipe-down. Use `.presentationDetents([.medium, .large])` so the sheet accommodates a 7-tile strip + claim button on small devices while staying compact on Pro Max.

`.fullScreenCover` is justified only for the **claim celebration itself** if you want a full confetti stage (à la Duolingo). Trade-off: more disruptive. KISS → keep it one sheet.

Popover is wrong (iPad-only semantics, awkward on iPhone).

Refs: Apple HIG > Patterns > Modality; `presentationDetents` (iOS 16+, stable on 26).

## 2. Calendar strip / 7-day progress

**Pattern: horizontal `HStack` of 7 day-tiles**, each a `Capsule` or rounded `VStack(day-letter, icon, checkmark)`. Three states:
- **claimed** (filled accent + checkmark, `opacity 1.0`)
- **today** (ring / border highlight + pulsing)
- **locked** (gray, `opacity 0.4`, lock icon)

Industry refs:
- **Duolingo** streak flame + day row (locked = grayed circle).
- **Pokémon GO** research breakthrough — 7 stamps, claimed stamps stamped, today glows.
- **Apple Activity rings** — concentric, but the *state logic* (closed/open/not-started) maps directly.

SwiftUI: `HStack(spacing: 8)` of `DayTile` views, `ScrollView` horizontal only if needed (7 tiles fit iPhone SE width at ~40pt each — fine without scroll). For iPad, center the strip and cap width to `400pt` via `frame(maxWidth:)`. Do not mimic Activity rings — over-engineered for a reward screen.

## 3. Claim animation

**Recommendation: spring scale-pop on the coin symbol + `.symbolEffect(.bounce)` on SF Symbol + a 1-second count-up on the coin counter.** End with a confetti burst of `Canvas`-drawn particles (stock SwiftUI, no deps).

- **Coin symbol**: `Image(systemName: "coins.fill").symbolEffect(.bounce, options: .repeat(1))` (iOS 17+, baseline on 26).
- **Count-up**: `TimelineView` or a simple `withAnimation(.easeOut(duration: 0.8))` driving an `Int` from `oldCoins → newCoins`.
- **Confetti**: a `Canvas` view drawing ~30 colored circles with random offset/rotation, animated via `withAnimation(.snappy)`. ~40 lines. Avoids SwiftUI Confetti third-party lib.
- **Reward stage**: `.transition(.scale.combined(with: .opacity))` on the claimed-tile checkmark.

WWDC refs: **"Symbol images"** (WWDC23, symbol effects), **"Explore SwiftUI animations"** (WWDC23, `KeyframeAnimator` / phased animations), **"Discover Observation in SwiftUI"** (WWDC23) for driving count-up from a `@Observable` model. HIG Motion: animation must convey meaning, not decorate; keep duration ≤ 600ms per micro-step.

## 4. Haptic feedback

**Use `UINotificationFeedbackGenerator.success` for the claim moment**, plus a `.light` impact on each "stamp" of the today-tile.

- `.success` = positive, "reward earned" — semantically correct for a coin payout.
- `.warning` = ambiguous / caution — wrong fit.
- `.error` = already used by `Feedback.wrong()`.
- Mid-intensity `.medium` impact optional for confetti pop, but `.light` (already wired as `Feedback.celebrationTap`) is enough.

Existing codebase pattern (verified in `Game/Feedback.swift`): `Feedback.enabled` static toggle mirrors `Settings.hapticsEnabled`, checked per-call. **Reuse, don't reinvent** — add a `Feedback.reward()` that calls `notifyGen.notificationOccurred(.success)` after `prepareCelebration()`. Reuse the prepare→burst→chime rhythm already used for the correct-word wave. No new generator instances.

## 5. Entry points & frequency

**Recommendation: auto-popup once per day + persistent Home toolbar icon.**

- **Auto-popup** on app launch when `canCheckInToday && !hasSeenCheckinSheetToday`. One interruption per day max — HIG allows this for value-delivery moments (cf. App Store review prompts: max frequency gating).
- **Manual entry**: small calendar icon (`Image(systemName: "calendar.badge.checkmark")`) in `HomeView` toolbar — lets players preview tomorrow's reward, builds anticipation, and gives a recovery path if they dismissed too fast.
- **Never** use `.fullScreenCover` on launch (feels like an ad). Sheet at `.medium` detent after a 0.4s delay so the game state settles first.

Trade-off: auto-popup risks annoyance if the reward is weak; manual-only tanks engagement (Duolingo A/B tests showed auto-popup lifts D7 retention materially). Hybrid wins.

## 6. Accessibility

- **VoiceOver labels** per tile: `"Monday, day 2 of 7, claimed"` / `"Tuesday, day 3, today, double tap to claim"` / `"Wednesday, locked"`. Use `.accessibilityLabel` + `.accessibilityValue` (state) + `.accessibilityHint` ("Claims 50 coins"). Group the strip in one `.accessibilityElement(children: .contain)` container.
- **Reduce Motion** (`@Environment(\.accessibilityReduceMotion)`): swap confetti + bounce for a static 0.2s opacity fade-in and an instant coin count jump. Skip `symbolEffect(.bounce)` entirely. Keep haptics (motion-reduce ≠ haptic-reduce).
- **Reduce Transparency**: solid sheet background instead of `.ultraThinMaterial`.
- **Dynamic Type**: day tiles must scale; cap tile height at `@ScaledMetric(44)` and let the strip wrap vertically on XL sizes via `Layout` (iOS 16+) — or fall back to 2 rows.
- **Color**: never rely on color alone for claimed/locked — pair with checkmark/lock SF Symbols (already done in §2).

Refs: Apple HIG > Accessibility > Motion; HIG > Inclusion; WWDC22 "Compose accessible layouts."

## Unresolved Questions

- **Coin economy**: what reward curve (linear 10/20/30… vs escalating 5/10/20/50/100/200/500)? Affects count-up animation duration tuning.
- **Streak-break policy**: missing a day — full reset, or freeze (Duolingo "Streak Freeze")? Impacts data model + UX for "lost streak" screen (out of scope here).
- **Offline / restore**: if player closes app mid-claim, idempotency key needed so re-launch doesn't double-pay.
- **First-launch onboarding**: should day 1 auto-trigger, or wait until post-tutorial? Affects `hasSeenCheckinSheetToday` seeding.

## Recommendation

**Present as a `.sheet` at `.medium` detent, auto-fired once daily on launch when `canCheckInToday` and not yet seen, with a redundant `calendar.badge.checkmark` toolbar icon in `HomeView` for manual review.** Layout = `HStack` of 7 `DayTile` capsules (locked/today/claimed states) above a prominent "Claim" button. On claim: reuse the existing `Feedback.prepareCelebration() → celebrationTap → celebrationChime()` haptic rhythm, animate the today-tile with `.transition(.scale)` + `symbolEffect(.bounce)` on the coin SF Symbol, count up the coin total via `withAnimation(.easeOut(0.8))`, and overlay a stock-SwiftUI `Canvas` confetti burst (no deps) — all gated by `@Environment(\.accessibilityReduceMotion)` to a static fade. Honor `Feedback.enabled` for haptics. This is KISS-compliant, reuses the codebase's existing feedback primitives, stays under 200 lines of net-new SwiftUI, and matches the modal-reward pattern proven by Duolingo/Pokémon GO without copying their visual noise.
