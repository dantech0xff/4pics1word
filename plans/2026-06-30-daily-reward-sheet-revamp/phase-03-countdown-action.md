# Phase 03 — Countdown Action Section

## Context links
- Parent plan: `../plan.md`
- Dependency: Phase 01/02 not strictly required (disjoint region L156–182) but shared reduce-motion discipline; serial recommended.
- Research: `../research/researcher-02-report.md` (§1–§7).
- Scout: `../scout/scout-01-report.md` (L156–182 actionSection).
- Source: `4pics1word/Views/CheckInView.swift`.

## Overview
- Date: 2026-06-30
- Description: Delete redundant post-claim copy (L174, L176). Render single live line `Next reward [coin] {N} in HH:MM:SS` via `TimelineView(.periodic(by:1))`; per-digit `.numericText()` (3-split h/m/s); reduce-motion gated. Preserve next-reward amount inline.
- Priority: P2
- Implementation status: pending
- Review status: pending

## Key Insights (researcher-02)
- `TimelineView(.periodic(from: Date(), by: 1))` > `Timer.publish`: no `@State`/`onReceive`/cancel wiring; auto-unmounts on sheet dismiss (KISS+DRY); matches L449 shimmer pattern.
- DST-safe midnight: `Calendar.date(byAdding:.day, value:1, to: startOfDay)` — NOT `+86400` (wrong ±1h on DST days).
- **Footgun:** `.contentTransition(.numericText())` no-ops inside TimelineView without explicit `.animation(value:)` providing context. Single interpolated `Text("12:34:56")` → opaque string swap, no per-digit slide. Fix = 3 sibling `Text`s (h/m/s) each w/ own `.animation(value: <unit Int>)`; colons static.
- `reduceMotion` (L9) MUST gate BOTH `.contentTransition` AND `.animation` (partial gating = broken).
- Midnight rollover: when `nextMidnight <= now`, `max(0,…)` clamps → `00:00:00`. Surrounding `if model.canCheckInToday` (L158) re-evals each TimelineView render → branch flips to Claim button automatically; no stale countdown.
- A11y: spoken "HH:MM:SS" is hostile → `.accessibilityElement(children:.ignore)` + `.accessibilityLabel("Next reward, {N} coins, available in {H} hours {M} minutes")` (coarse, not per-second).
- Use `ctx.date` inside TimelineView (not `Date()`) → SwiftUI coalesces in previews/tests.

## Requirements
1. Delete L174 (`Text("Come back tomorrow")`) + L176 (`Text("Next reward: \(nextReward) coins")`).
2. Single line: `Next reward [bitcoinsign.circle.fill] {nextReward} in HH:MM:SS`, counting to local midnight.
3. Ticks every 1s via `TimelineView(.periodic(by:1))`.
4. Per-digit slide anim on h/m/s; colons static; reduce-motion → plain Text no motion.
5. `nextReward` amount preserved inline (info loss from deleted L176).
6. `.monospacedDigit()` on numerals; `.font(.subheadline)`; amount primary, "in" + timer secondary.
7. VoiceOver label = spoken words ("Next reward, N coins, available in H hours M minutes").
8. Fits single line on iPhone SE width at `.accessibility2` cap.
9. No `Timer.publish`, no `@State` `now`, no `onReceive`, no `onDisappear` cancel (existing L69–72 untouched).

## Architecture

### Replace post-claim branch (L171–181)
```swift
} else {
    let nextReward = CheckIn.reward(forStreakDay: model.progress.streakDays + 1)
    CountdownLine(nextReward: nextReward, reduceMotion: reduceMotion)
        .accessibilityIdentifier("CheckInCountdown")
}
```

### New private struct `CountdownLine` (in same file, below `CheckInView`)
Keeps `actionSection` readable; isolates TimelineView scope.
```swift
private struct CountdownLine: View {
    let nextReward: Int
    let reduceMotion: Bool

    var body: some View {
        TimelineView(.periodic(from: Date(), by: 1)) { ctx in
            let remaining = max(0, Self.secondsUntilMidnight(from: ctx.date))
            let h = Int(remaining) / 3600
            let m = Int(remaining) / 60 % 60
            let s = Int(remaining) % 60
            HStack(spacing: 4) {
                Text("Next reward").foregroundStyle(.primary)
                Image(systemName: "bitcoinsign.circle.fill")
                    .foregroundStyle(.yellow)
                Text("\(nextReward)").monospacedDigit().foregroundStyle(.primary)
                Text("in").foregroundStyle(.secondary)
                timeUnit(h)                       // 2-digit Text
                Text(":").foregroundStyle(.secondary)
                timeUnit(m)
                Text(":").foregroundStyle(.secondary)
                timeUnit(s)
            }
            .font(.subheadline)
            .lineLimit(1).minimumScaleFactor(0.8)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Next reward, \(nextReward) coins, available in \(h) hours \(m) minutes")
        }
    }

    @ViewBuilder
    private func timeUnit(_ value: Int) -> some View {
        let txt = Text(String(format: "%02d", value)).monospacedDigit()
        if reduceMotion {
            txt.foregroundStyle(.secondary)
        } else {
            txt.foregroundStyle(.secondary)
                .contentTransition(.numericText())
                .animation(.easeOut(duration: 0.15), value: value)
        }
    }

    private static func secondsUntilMidnight(from date: Date) -> TimeInterval {
        let cal = Calendar.current
        let startToday = cal.startOfDay(for: date)
        guard let nextMidnight = cal.date(byAdding: .day, value: 1, to: startToday)
        else { return 0 }
        return nextMidnight.timeIntervalSince(date)
    }
}
```
Notes:
- `reduceMotion` passed in from `CheckInView` env (L9) — no new `@Environment` in child.
- `.animation(value:)` keyed per-unit Int → `.contentTransition` gets its diff context.
- Colons = plain `Text(":")`, no transition.
- `.lineLimit(1).minimumScaleFactor(0.8)` → fits SE/AX2 width.
- Force-unwrap avoided via `guard` (KISS; Calendar always returns valid next-day).
- A11y label coarse (h/m only — seconds noise hostile); no per-tick VoiceOver churn.

## Related code files
- `4pics1word/Views/CheckInView.swift` — L156–182 (`actionSection`), L9 (`reduceMotion` env), L449 (TimelineView precedent), L83 (`.numericText` precedent).
- Read-only: `4pics1word/Game/CheckIn.swift` L7–10 (`reward(forStreakDay:)`).

## Implementation Steps
1. Delete L174 (`Text("Come back tomorrow")`) + L176–178 (`Text("Next reward: \(nextReward) coins")` + styling).
2. Replace L173–179 `VStack` block w/ `CountdownLine(nextReward: nextReward, reduceMotion: reduceMotion).accessibilityIdentifier("CheckInCountdown")`. Keep L172 `let nextReward = …` (passed in).
3. Keep L180 `.accessibilityElement(children: .combine)` only if still needed — `CountdownLine` sets its own; drop the outer modifier (DRY).
4. Add `private struct CountdownLine: View` per Architecture (place above `private enum DayTileState` L258 or below `CheckInView`).
5. Build: `xcodebuild -project 4pics1word.xcodeproj -scheme 4pics1word -destination 'platform=iOS Simulator,name=iPhone 16' build`.
6. Manual: claim reward → countdown appears, ticks each second, per-digit slide (reduce-motion OFF); enable reduce-motion → plain text, no slide; VoiceOver reads spoken label.

## Todo list
- [ ] Delete L174 + L176–178 copy
- [ ] Replace post-claim VStack w/ `CountdownLine(...)`
- [ ] Drop now-redundant outer `.accessibilityElement(children:.combine)` (L180)
- [ ] Add `CountdownLine` struct (TimelineView + 3-split + reduce-motion gate)
- [ ] Add `secondsUntilMidnight(from:)` DST-safe helper
- [ ] Add `.accessibilityIdentifier("CheckInCountdown")`
- [ ] Verify single-line fit at SE width + AX2
- [ ] `xcodebuild build` green

## Success Criteria
- Post-claim: single line `Next reward [coin] {N} in HH:MM:SS`; no "Come back tomorrow"/"Next reward: N coins".
- Countdown decrements every 1s to local midnight; never negative (`00:00:00` floor).
- Per-digit slide on h/m/s when reduce-motion OFF; plain text when ON.
- Amount visible inline next to coin glyph.
- VoiceOver speaks "Next reward, N coins, available in H hours M minutes" (no "HH:MM:SS").
- Sheet dismiss/recreate leaves no ticking timer leak (TimelineView auto-cancels).
- Build green.

## Risk Assessment
| Risk | Mitigation |
|---|---|
| `.contentTransition` no-ops inside TimelineView | Explicit `.animation(.easeOut(0.15), value: <unit>)` per `timeUnit` (researcher-02 §3). Verify per-digit slide manually. |
| Fallback to single `Text` w/ `.opacity` transition if 3-split heavy | Documented as researcher-02 §3 simpler fallback; only adopt if 3-split proves buggy. Default = 3-split. |
| Single-line overflow at AX2 / SE width | `.lineLimit(1).minimumScaleFactor(0.8)`. If still overflow → drop "Next reward" prefix to "Next" (defer). |
| DST day ±1h bug | `Calendar.date(byAdding:.day, value:1,…)` not `+86400` (researcher-02 §2). |
| Midnight rollover: stale countdown past 00:00 | `max(0,…)` floor → `00:00:00`; surrounding `if model.canCheckInToday` (L158) re-evals each render → flips to Claim button. No `onChange` hook needed (researcher-02 §5). |
| App backgrounded across midnight → `canCheckInToday` stale | Out of scope (researcher-02 Q4); model re-evals on next appear/objectWillChange. Low-risk per brief. |
| VoiceOver per-second churn | Static label computed each render but coarse (h/m only); acceptable. Defer `updatesFrequently` trait. |
| Sheet lifecycle leak | `TimelineView(.periodic)` auto-cancels on unmount. Do NOT add `Timer.publish` "for safety" (researcher-02 §5). |

## Security Considerations
None — UI-only. No data/auth/network surface. `ctx.date` is system clock; no PII.

## Next steps
→ Phase 04 (tests + a11y + build/test green). Breaking change: `testClaimShowsThenComeBackTomorrow` (L46–58) + `testToolbarButtonReopensSheetAfterDismiss` (L99–100) assert deleted "Come back tomorrow" text → must update to `CheckInCountdown` identifier.
