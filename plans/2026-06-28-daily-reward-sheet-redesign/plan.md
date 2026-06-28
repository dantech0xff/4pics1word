---
title: "Daily Reward Sheet Redesign"
description: "Force-claim gate + 3/4 two-row grid + enriched DayTiles for CheckInView"
status: implemented
priority: P2
effort: 7h
branch: master
tags: [ui, ux, swiftui, daily-reward]
created: 2026-06-28
completed: 2026-06-29
---

# Plan — Daily Reward Sheet Redesign

## Goal
Redesign `CheckInView` bottom sheet per 3 non-negotiable user reqs:
1. **Force-claim gate** — sheet non-dismissible while reward claimable (no swipe, no X). Free after claim.
2. **3/4 two-row grid** — Days 1–3 row, Days 4–7 row, centered (user explicitly chose over 3+3+1).
3. **Bigger, richer cells** — ~110pt (3-up) / ~85pt (4-up) tiles w/ day label, coin icon, value, jackpot badge (D7), TODAY pill, claimed ✓, locked 🔒.

## Scope
**Modify:** `CheckInView.swift`, `AppRootView.swift` (1 modifier), `CheckInUITests.swift` (1 test contract), `Feedback.swift` (+1 warning fn).
**Do NOT touch:** `CheckIn.swift`, `AppModel.swift`, `HomeView.swift`, `ConfettiOverlay` (keep as-is), `project.pbxproj` (auto-sync groups).

## Architecture decisions
- `canDismiss = !model.canCheckInToday` — recomputed from existing observable state. Synchronous flip on `checkIn()`.
- `.interactiveDismissDisabled(!canDismiss)` on `CheckInView` inside `.sheet{}` (content side, not presentation side). Per researcher-01 §1–3.
- **Pattern A** Close button: always rendered, `.disabled(!canDismiss)`, `.opacity(0.4)` when disabled, `.accessibilityHint` describes gate. Per researcher-01 §2/§4 — don't trap VoiceOver users.
- Warning haptic on Close-tap-when-disabled via new `Feedback.warning()` (uses `UINotificationFeedbackGenerator(.warning)` — keep KISS, no new generators).
- DayTile goes from 44pt capsule → square tile with fixed `@ScaledMetric` height per row count. Per researcher-02 §3.
- Visual states per researcher-02 §4: claimed (green ✓, dim, scale 0.95), today (pulse + glow + TODAY pill), locked (padlock + 30% scrim, reward visible), jackpot (golden gradient + JACKPOT badge D7).

## Phases

| # | Phase | Status | Effort | File |
|---|---|---|---|---|
| 01 | Force-claim dismiss gate | done | 2h | [phase-01-force-claim-dismiss-gate.md](./phase-01-force-claim-dismiss-gate.md) |
| 02 | Two-row grid 3/4 layout | done | 2h | [phase-02-two-row-grid-layout.md](./phase-02-two-row-grid-layout.md) |
| 03 | Enriched DayTile | done | 2h | [phase-03-enriched-daytile.md](./phase-03-enriched-daytile.md) |
| 04 | Tests & accessibility pass | done | 1h | [phase-04-tests-accessibility-pass.md](./phase-04-tests-accessibility-pass.md) |

**Total: 7h.**

## Phase ordering & parallelism
- **01 must ship first** (defines `canDismiss` contract + warning haptic used by later phases' test fixtures).
- **02 & 03 are tightly coupled** (layout defines cell sizing; cell sizing defines layout). Recommend serial: 02 → 03. Could parallelize if a stub DayTile signature is locked first — not worth the merge pain for a 7h plan.
- **04 runs last** (validates the gated Close contract; depends on 01).

## Success criteria (plan-level)
- Sheet cannot dismiss (swipe or X) while `model.canCheckInToday == true`.
- After claim (or if pre-claimed on open), swipe + X both work.
- Days render as two centered rows: [1,2,3] and [4,5,6,7].
- Day 7 visibly distinct (jackpot treatment).
- All existing UI tests pass (with updated `testToolbarButtonReopensSheetAfterDismiss`).
- `xcodebuild build` + `test` green on iPhone 16 sim.

## Out of scope (YAGNI)
- Countdown timer ("next reward in 18h") — researcher-02 §2 #10; defer.
- Mystery "?" tile — researcher-02 §2 #8; defer.
- Streak flame counter — researcher-02 §2 #7; defer.
- Drag-blocked haptic — researcher-01 §5 (no public callback); skip.
- iPad form-sheet verification — open Q, defer to device test.

## Unresolved questions
1. Should Close button auto-enable mid-animation (before confetti ends) or wait for full celebrate cycle? → Recommend immediate (claim is the gate, not animation).
2. Reduce-motion: pulse disabled — does TODAY pill still render? → Yes (pill is static, pulse only animates).
3. Should jackpot tile (D7) in 4-up row be visually larger than D4–D6 or same cell size w/ golden bg only? → Same size + golden bg + JACKPOT badge (keeps grid clean; researcher-02 §3 warns against >2× size).
