---
title: "Daily Reward Sheet Revamp — 3-3-1 Grid, Claimed Check, Countdown"
description: "Redesign daily-reward sheet: 3-3-1 grid w/ full-width Day-7 jackpot, checkmark-only claimed tiles, live midnight countdown replacing redundant copy."
status: completed
priority: P2
effort: 4h
branch: master
tags: [ui, ux, swiftui, daily-reward, redesign]
created: 2026-06-30
---

# Plan — Daily Reward Sheet Revamp

## Goal
Three product reqs (all in `CheckInView.swift` only):
1. **Grid 3-3-1** — split `dayStrip` (L99–112) into 3+3 rows + full-width Day-7 jackpot row for richer UI. Fixes today's 4-vs-3 tile width mismatch (researcher-01 §1).
2. **Claimed = checkmark only** — swap (not overlay) the coin `Image` (L312) → green check when `state == .claimed`; delete dead overlay arm (L367–372). Column geometry unchanged (same `.title3`).
3. **Countdown replaces copy** — delete L174 + L176; render single line `Next reward [coin] {amount} in HH:MM:SS` via `TimelineView(.periodic(by:1))`, per-digit `.numericText()` (3-split h/m/s), reduce-motion gated. Preserve amount inline.

## Scope
**Modify:**
- `4pics1word/Views/CheckInView.swift` — grid, jackpot tile, claimed cell, actionSection countdown.
- `4pics1wordUITests/CheckInUITests.swift` — fix 2 tests asserting deleted "Come back tomorrow" copy; add countdown + 3-3-1 assertions.

**Do NOT touch:** `CheckIn.swift`, `AppModel.swift`, `Feedback.swift`, `AppRootView.swift`, rewards array, `project.pbxproj`. Logic/haptics/fly-coin/confetti unchanged.

## Architecture decisions (cited)
- **3-3-1 = manual HStack stack, NOT LazyVGrid/Grid** — no public colspan in `Grid`; HStack already works + supports `@ScaledMetric` (researcher-01 §1). Drop redundant `.frame(maxWidth:.infinity)` on 2nd HStack (L109).
- **Jackpot full-width = horizontal layout** when `isJackpot && state != .claimed`: `HStack { gift.fill + VStack(DAY 7 / 100) + Spacer + JACKPOT pill }`. Delete `jackpotBadge` overlay (L398–412) — pill moves inline. Locked/claimed jackpot falls back to vertical `contentColumn` (researcher-01 §3).
- **Claimed swap not overlay** — branch at L312 on `state == .claimed`; same `.title3` glyph height keeps `VStack(spacing:4)` (L307) balanced; reward number stays (researcher-01 §2).
- **Countdown = `TimelineView(.periodic(from: Date(), by: 1))`** — no `Timer.publish`/`@State`/`onReceive` (KISS+DRY, matches L449 shimmer pattern). DST-safe via `Calendar.date(byAdding:.day, value:1,…)` (researcher-02 §2).
- **Per-tick anim = 3 sibling `Text`s (h/m/s)** each `.contentTransition(.numericText())` + `.animation(.easeOut(0.15), value: <unit Int>)` — `.contentTransition` no-ops inside TimelineView without explicit `.animation(value:)` (researcher-02 §3). Colons static.
- **AX fallback** — jackpot horizontal layout flips to vertical `contentColumn` when `dynamicTypeSize.isAccessibilitySize` (avoids truncation at `.accessibility2` cap, researcher-01 risks).
- **iPad width** — sheet is `.medium` detent (AppRootView L25); accept form-sheet width as-is (prior plan decision). No `maxWidth` cap (YAGNI; verify in Phase 01).
- **MainActor default** — no new annotations. Keep reduce-motion/reduce-transparency/Dynamic-Type cap paths.

## Phases
| # | Phase | Status | Effort | File |
|---|---|---|---|---|
| 01 | 3-3-1 grid + full-width jackpot tile | done | 1h | [phase-01-grid-3-3-1-jackpot.md](./phase-01-grid-3-3-1-jackpot.md) |
| 02 | Claimed checkmark-only + spacing balance | done | 0.5h | [phase-02-claimed-checkmark.md](./phase-02-claimed-checkmark.md) |
| 03 | Countdown action section | done | 1.5h | [phase-03-countdown-action.md](./phase-03-countdown-action.md) |
| 04 | Tests, a11y, build verification | done | 1h | [phase-04-tests-a11y-build.md](./phase-04-tests-a11y-build.md) |

**Total: 4h.**

## Phase ordering
- **01 first** — layout defines all cell geometry; everything else depends on it.
- **02 after 01** — claimed-state swap touches same `contentColumn`/`DayTile.body` region shaped by 01.
- **03 parallel-safe w/ 02** — touches `actionSection` (L156–182), disjoint from `DayTile`. But serial is safer (shared reduce-motion discipline).
- **04 last** — validates all; fixes breaking UI tests.

## Success criteria (plan-level)
- Grid renders 3+3 equal-width tiles + 1 full-width jackpot row (no 4-vs-3 mismatch).
- Day-7 jackpot (unclaimed) shows horizontal layout w/ inline JACKPOT pill; locked/claimed falls back vertical.
- Claimed tiles show ONLY green checkmark (no coin behind); reward number still visible; column centered.
- Post-claim shows single line `Next reward [coin] {N} in HH:MM:SS`; no "Come back tomorrow"/"Next reward: N coins".
- Countdown ticks every 1s; per-digit slide anim; reduce-motion = plain text no motion.
- VoiceOver reads countdown as spoken words (not "HH:MM:SS").
- `xcodebuild build` + `test` green on iPhone 16 sim; UI tests updated + pass.

## Out of scope (YAGNI)
- Timer-publish fallback, `DateComponentsFormatter`, combine-based clock.
- `symbolEffect(.bounce)` flourish on gift.fill (researcher-01 optional — defer).
- Countdown on today-tile pill (researcher-02 Q3 — `actionSection` only per brief).
- `maxWidth` cap on iPad, localisation, mystery tile, streak-protect states.
- Cross-view coin-fly changes (anchor stays header counter).

## Resolved decisions (validation interview 2026-06-30)
1. **Grid container** → manual HStack stack (researcher-01 §1). ✅
2. **Jackpot layout** → horizontal HStack w/ inline pill, vertical fallback for locked/claimed/AX (researcher-01 §3). **[VALIDATED]**
3. **Claimed cell content** → checkmark swaps in at L312; **keep DAY label AND reward number** (number stays legible); delete overlay L367–372 (researcher-01 §2). **[VALIDATED]**
4. **Countdown engine** → `TimelineView(.periodic(by:1))`, 3-split h/m/s Texts + `.animation(value:)` (researcher-02 §1–3). ✅
5. **Copy format** → `Next reward [coin] {N} in HH:MM:SS`, single line w/ coin glyph before the amount. **[VALIDATED]**
6. **Tick animation** → subtle per-digit slide via `.numericText()` on each h/m/s Text (matches header counter); reduce-motion = plain text. **[VALIDATED]**

## Open questions (empirical only)
1. **VoiceOver cadence** — a11y label freeze at sheet-open vs per-tick. Default: static label w/ coarse "in N hours M minutes"; defer `updatesFrequently` trait unless requested.
2. **iPad jackpot width** — verify horizontal layout doesn't stretch absurdly wide on regular size class (Phase 01 empirical).
3. **Single-line countdown fit at AX2** — may need `.lineLimit(1)` + `.minimumScaleFactor(0.8)`; verify Phase 03.
