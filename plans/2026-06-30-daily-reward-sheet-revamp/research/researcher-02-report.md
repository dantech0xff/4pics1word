# Researcher 02 — Countdown Timer

## Files read
- `4pics1word/Views/CheckInView.swift` (574 lines). Relevant:
  - L9 `@Environment(\.accessibilityReduceMotion) private var reduceMotion` — reuse for animation gate.
  - L83 `.contentTransition(.numericText(value: Double(displayedCoins)))` — precedent; proven to work in this target.
  - L156–182 `actionSection`. Post-claim branch L171–181: stacked `Text("Come back tomorrow")` (L174) + `Text("Next reward: \(nextReward) coins")` (L176). Replace both.
  - L449 `TimelineView(.animation) { timeline in … }` — codebase already uses TimelineView for shimmer; same pattern idiomatic here.
  - L172 `CheckIn.reward(forStreakDay: model.progress.streakDays + 1)` — next reward value source.
  - L68 `.task { displayedCoins = model.progress.coins }` + L69–72 `onDisappear` cleanup — established lifecycle hygiene.

## Topic 1: Per-second tick source
Two candidates:

**A. `TimelineView(.periodic(from: Date(), by: 1)) { ctx in … }`** (RECOMMENDED)
- Declares cadence; SwiftUI supplies `ctx.date`. No `@State`, no `Combine` import, no `onReceive`.
- Auto-cancels when view leaves hierarchy → **no leak when sheet dismissed/recreated** (the explicit KISS ask).
- Pauses when scene backgrounded (low overhead); ticks again on foreground.
- Already-proven pattern in this file (L449 uses `.animation` schedule; `.periodic(by: 1)` is the slow-cadence sibling).

**B. `Timer.publish(every: 1, on: .main, in: .common).autoconnect()` + `@State var now` + `.onReceive`**
- Explicit but heavier: needs `@State`, sink wiring, and careful teardown. `autoconnect()` cancellable is auto-cancelled when the publisher goes out of scope, but it is easy to mis-wire (common-mode main-thread churn, accidental strong refs).
- Fights the file's established `TimelineView` style → DRY violation.

**Recommendation: A.** Honors KISS + DRY + matches L449. No `onDisappear` cancel needed (existing L69–72 stays untouched).

## Topic 2: Time-to-midnight computation + formatting
**Recipe (DST-safe, calendar-respecting):**
```swift
let cal = Calendar.current
let startToday = cal.startOfDay(for: Date())
let nextMidnight = cal.date(byAdding: .day, value: 1, to: startToday)!  // force-unwrap safe: always valid
let remaining = max(0, nextMidnight.timeIntervalSinceNow)
```
- `startOfDay` is local-calendar-local-tz → correct local midnight.
- Prefer `cal.date(byAdding:.day, value:1, …)` over `.addingTimeInterval(86400)` — the latter is wrong by ±1h on DST "spring forward / fall back" days; the calendar form stays correct.
- `max(0, …)` guards the rollover edge (Topic 5).

**Formatting:** prefer **manual `String(format: "%02d:%02d:%02d", h, m, s)`**.
- Fixed 2-digit width → stable layout, pairs with `.monospacedDigit()` (matches header counter L82).
- `DateComponentsFormatter` is heavier (allocates on each tick if not cached) and `.positional` collapses leading-zero units ("0:34:56") unless `zeroFormattingBehavior = [.pad]` is set — fragile.
- If a colloquial variant is ever wanted later, cache formatter as `static let` (init cost ~µs × 60 ticks/min adds up).

**Inside `TimelineView`:**
```swift
TimelineView(.periodic(from: Date(), by: 1)) { ctx in
  let r = max(0, nextMidnight(using: ctx.date).timeIntervalSinceNow)
  let h = Int(r) / 3600, m = Int(r) / 60 % 60, s = Int(r) % 60
  …
}
```
Use `ctx.date` (not `Date()`) so SwiftUI can coalesce / replay in previews & tests.

## Topic 3: Per-tick animation
**The TimelineView gotcha:** `.contentTransition(.numericText())` fires only when the `Text`'s value (an `Equatable` input used to build the `Text`) **changes between two renders**. `TimelineView` re-runs the closure every tick with a fresh `Date` — so the body is rebuilt, but `.numericText()` still needs a per-value diff on the specific `Text` it's attached to. Two pitfalls:
1. If the whole `"12:34:56"` is one interpolated `Text(String)`, `.numericText()` may treat it as a single opaque string change → animation degrades to a hard swap, not a per-digit slide.
2. `.contentTransition` needs an **animation context** to actually run. `TimelineView` does not open one implicitly.

**Recommended approach (works inside TimelineView, reduce-motion-friendly):**
- Split into three sibling `Text`s (h / m / s) inside an `HStack`, each `.monospacedDigit()` + `.contentTransition(.numericText())` + `.animation(.easeOut(duration: 0.15), value: <that unit Int>)`. The `.animation(value:)` provides the implicit context `.contentTransition` needs; per-unit split lets `.numericText()` identify the changed digit run cleanly.
- Colons as static `Text(":")` between — they don't transition.
- Gate with `reduceMotion` (L9): if true, drop `.contentTransition` + `.animation` entirely → plain `Text`s, no motion. Matches existing reduce-motion discipline (L189, L252, L447).

**Simpler fallback** (if 3-split feels heavy): one `Text` with the full `String(format:)`, `.contentTransition(.opacity)`, `.animation(.easeOut(duration: 0.15), value: s)` (key off seconds Int). Crossfade, not per-digit, but trivially correct. Still reduce-motion-gated.

## Topic 4: Format & copy
**Recommendation:** `Next reward in 12:34:56` (colon form), `.monospacedDigit()`.
- Densest, fixed-width, instantly readable as a timer, matches existing tile/counter typography.
- Avoids the chatty `12h 34m 56s` form; also avoids `HHh MMm SSs` ambiguity for non-tech users.
- Per-tick animation is cleaner on a fixed-width field.

**Preserve next-reward amount (info loss from removing L176):**
Yes — recommend folding into the same line with a small coin glyph:
`Next reward · ⬤ 35 · in 12:34:56`  (or `Next reward (35) in 12:34:56`)
- Keeps the row count at ONE (matches the product ask: "replace BOTH lines with a single countdown").
- Use `Image(systemName: "bitcoinsign.circle.fill")` (already used L312) + `Text("35")` + dim `Text("in 12:34:56")`.
- Subtle styling: `.font(.subheadline)`, primary for amount, `.secondary` for "in" + timer, so the countdown reads as the live element.

Concrete single-line layout:
```
[bitcoinsign.circle.fill]  35  ·  in  12:34:56
```
Stays one line on iPhone SE width if `.font(.subheadline)` + tight spacing.

## Topic 5: Midnight rollover edge
- When `nextMidnight <= now`, computed `remaining` is clamped to `0` (Topic 2 `max(0,…)`); display reads `00:00:00` — never negative.
- `model.canCheckInToday` is the canonical gate for the `actionSection` branch (L158). Once midnight passes, next re-eval flips it → `actionSection` re-renders to the Claim button (L160–170). The `TimelineView` closure is inside the `else` branch, so it unmounts automatically — **no stale countdown**.
- Re-eval trigger: model recompute happens on next appear / `objectWillChange` / app-foreground notification. If sheet stays open across midnight (rare), add a 1-rep `.onChange(of: model.canCheckInToday)` is NOT needed — `TimelineView` ticks `ctx.date`, and the surrounding `if model.canCheckInToday` re-evaluates each render anyway.
- **Low-risk** per product brief (sheet typically dismissed by then). Ship as-is.

## Risks / gotchas
1. **DST:** use `Calendar.date(byAdding:.day, value:1, …)`, NOT `+86400`. Off-by-one-hour on DST days otherwise.
2. **`.contentTransition` inside TimelineView needs `.animation(value:)` or it silently no-ops.** Most common footgun.
3. **`reduceMotion` (L9) must gate BOTH `.contentTransition` and `.animation`.** Don't gate just one — partial motion defeats the setting.
4. **Formatter perf:** if you fall back to `DateComponentsFormatter`, cache as `static let` — per-tick alloc is wasteful. Manual `String(format:)` has no such concern.
5. **Sheet lifecycle:** `TimelineView(.periodic)` is safe across dismiss/recreate — no `onDisappear` cancel needed. Do NOT also keep a `Timer.publish` "for safety"; that's the leak the brief warns against.
6. **Single-line width:** verify `bitcoinsign.circle.fill + 35 + "in 12:34:56"` fits at Dynamic Type accessibility sizes — may need `.lineLimit(1)` + `.minimumScaleFactor(0.8)` or fallback to two lines for AX5. Existing tiles cap at `.accessibility2` (L296); mirror that.
7. **A11y label:** combine into one `accessibilityElement(.container)`-style label: `"Next reward, 35 coins, available in 12 hours 34 minutes"`. Spoken-out HH:MM:SS is hostile to VoiceOver. Use `.accessibilityLabel` + `.accessibilityElement(children: .ignore)`.

## Unresolved questions
1. **Exact copy:** is `(35)` parenthetical OK, or product wants `· 35 ·` dot-separated, or coin-icon-only (no number word)? — needs product/design sign-off.
2. **VoiceOver cadence:** should the a11y label update each second (noisy) or freeze at sheet-open until minute boundary? Recommend freeze + `.accessibilityAddTraits(.updatesFrequently)`-style hint, but a11y spec not yet finalized.
3. **Should the post-claim timer also show on the today-tile ("TODAY" pill L415) when claimed early in day, or only in `actionSection`?** Scope says `actionSection` only; confirm.
4. **TimelineView foregrounding behavior:** if app backgrounded at 23:59:50 and foregrounded at 00:00:05, does `model.canCheckInToday` re-eval without a manual `NotificationCenter` hook? Depends on `AppModel` internals (not read here) — confirm in plan phase.
