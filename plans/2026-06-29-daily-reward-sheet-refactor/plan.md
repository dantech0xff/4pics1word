---
title: "Daily Reward Sheet Refactor"
description: "Lock sheet to non-expandable + rework reward cells (uniform grid, soft locked, jackpot, fly-to-wallet)"
status: pending
priority: P2
effort: 7h
branch: master
tags: [ui, ux, refactor, swiftui, daily-reward]
created: 2026-06-29
---

# Plan — Daily Reward Sheet Refactor

## Goal
Two product reqs:
1. **Bottom sheet non-expandable** — kill drag-to-fullscreen via single `.medium` detent.
2. **Reward cell rework** — higher polish: uniform grid, soft locked state, jackpot day-7, progress dots, spring + coin fly, reduce-motion-safe.

## Scope
**Modify:**
- `4pics1word/Views/AppRootView.swift` (line 25 detent).
- `4pics1word/Views/CheckInView.swift` (grid, DayTile, claim animation, a11y).
- `4pics1wordUITests/CheckInUITests.swift` (update + new assertions for dots/non-expand).

**Do NOT touch:** `4pics1word/Game/CheckIn.swift`, `4pics1word/Game/AppModel.swift`, `4pics1word/Game/Feedback.swift`, `project.pbxproj`. Logic, rewards array, haptics unchanged.

## Architecture decisions
- **Detent:** `[.medium]` single — single detent = no expand target = non-expandable by construction (researcher-01 §2). Keep `.interactiveDismissDisabled(!model.canCheckInToday)` + `.presentationDragIndicator(.visible)`.
- **iPad caveat:** `.presentationDetents` ignored on regular size class; form-sheet grabber has no public lock API (researcher-01 §5). **Accept** form-sheet on iPad. No hard lock promise.
- **Grid:** uniform 4+3 (all same cell height) — kills dual `threeHeight/fourHeight` (DRY). 7-across rejected (too narrow on SE).
- **Locked softening:** drop `Color.black.opacity(0.3)` scrim → desaturate + `.ultraThinMaterial` lock chip (researcher-02 §4).
- **Jackpot D7:** `gift.fill` icon (vs `bitcoinsign.circle.fill` days 1–6), golden gradient — same cell footprint (no grid break, researcher-02 §5).
- **Progress dots:** 7-dot row (filled/ring/hollow) above grid (researcher-02 §6).
- **Claim animation:** spring tap + coin fly via `matchedGeometryEffect` to **header coin counter** (same view — KISS). Cross-view HUD fly = out of scope. **[VALIDATED]**
- **Confetti scope:** Day-7 jackpot claim only (not every claim). Everyday claims get coin-fly + haptic. Makes D7 feel special. **[VALIDATED]**
- **iPad:** accept form-sheet + resize grabber as-is (no public lock API in iOS 26). **[VALIDATED]**
- **A11y:** Dynamic Type cap `.accessibility2` (not `.accessibility3`); refined VoiceOver labels w/ "claim in N days".
- **MainActor default** — no new `@MainActor` annotations.

## Phases
| # | Phase | Status | Effort | File |
|---|---|---|---|---|
| 01 | Lock sheet detent | pending | 0.5h | [phase-01-lock-sheet-detent.md](./phase-01-lock-sheet-detent.md) |
| 02 | Uniform grid + progress dots | pending | 1.5h | [phase-02-uniform-grid-layout.md](./phase-02-uniform-grid-layout.md) |
| 03 | Cell state polish | pending | 2h | [phase-03-cell-state-polish.md](./phase-03-cell-state-polish.md) |
| 04 | Claim animation (spring + fly) | pending | 2h | [phase-04-claim-animation.md](./phase-04-claim-animation.md) |
| 05 | Tests & a11y verify | pending | 1h | [phase-05-tests-a11y-verify.md](./phase-05-tests-a11y-verify.md) |

**Total: 7h.**

## Phase ordering
- **01 ships first** — 1-line fix, instant win, unblocks nothing but de-risks product bug immediately.
- **02 → 03 serial** — layout defines cell sizing; cell polish builds on layout (tight coupling, same as prior plan).
- **04 after 03** — fly animation needs final cell geometry + header anchor stable.
- **05 last** — validates all phases end-to-end.

## Success criteria (plan-level)
- Sheet CANNOT drag-to-fullscreen on iPhone (single `.medium` detent; no snap target).
- 7 cells render uniform size (4+3); no dual row-height.
- Locked cells read "coming soon" not "broken" (desaturated, no black scrim).
- Day 7 jackpot unambiguous (`gift.fill` + golden gradient + JACKPOT pill).
- 7-dot progress row reflects claimed/today/locked counts.
- Claim = spring + coin flies to header counter (reduce-motion: instant crossfade).
- Dynamic Type capped `.accessibility2`; VoiceOver labels w/ "claim in N days".
- `xcodebuild build` + `test` green on iPhone 16 sim; existing UI tests pass (updated).

## Out of scope (YAGNI)
- Countdown timer / "next reward in 18h".
- Mystery/random tile, battle-pass tiers, broken-streak/frozen/protect states.
- Cross-view coin fly to Home HUD (anchor = header counter only).
- iPad hard-lock via custom overlay modal.
- Per-cell particle bursts, 3D flip, haptic-only feedback.
- Localisation width audit (DE/FR/JP pill widths) — flagged in unresolved Qs.

## Resolved decisions (validation interview 2026-06-29)
1. **Coin fly anchor** → header counter inside sheet (KISS, same view). ✅
2. **Confetti scope** → Day-7 jackpot claim only. ✅
3. **iPad sheet** → accept form-sheet + resize grabber (no public lock API). ✅

## Open questions (minor / empirical)
1. **iPad grabber** — confirm empirically on iPad sim whether `[.medium]` applies (expected: ignored). Hard lock = custom overlay (out of scope).
2. **iPhone SE (375pt) fit** — 4+3 uniform grid + dots + claim button must fit `.medium`. Verify; if cramped, fall back to `.fraction(0.6)` single detent (still non-expandable). Empirical in Phase 02.
3. **Coin fly particle count** — 1 coin (KISS default) vs N-coin swarm (= reward value). Default 1; revisit if feels weak.
4. **JACKPOT pill localisation** — 9pt heavy caps "JACKPOT"/"TODAY" widths in DE/FR/JP may overflow. Defer unless shipping non-English.
