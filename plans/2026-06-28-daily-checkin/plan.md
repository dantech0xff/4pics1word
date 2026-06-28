---
title: "Daily Check-in / Streak Rewards"
description: "Once-per-day coin claim with a 7-day escalating streak loop, presented as a sheet from Home."
status: done
priority: P2
effort: 8h
branch: master
tags: [feature, economy, ui]
created: 2026-06-28
completed: 2026-06-28
---

## Decision Point — RESOLVED: Option B (additive)

Task said "only receive coin via daily check-in." Conflicts with the existing solve-reward economy (`Economy.reward(forTier:)`, granted on level-solve at `4pics1word/Game/AppModel.swift:64`).

- **Option A (strict)**: Remove `Economy.reward` from `handleSolved`. Check-in = sole coin source.
- **Option B (additive)**: Keep solve-rewards. Check-in is an *additional* source.

**Chosen: Option B** (user-confirmed 2026-06-28; reversible; preserves existing feature + its tests).

---

## Overview

Add a once-per-calendar-day coin claim with a 7-day escalating streak loop (`20/25/30/35/40/50/100`, weekly total 300, then wrap). Persist on existing `Progress` (free migration via custom `decodeIfPresent` decoder — synthesized Codable does NOT honor property defaults, so a custom `init(from:)` was required for true forward-compat). Present as a `.sheet` at `.medium`/`.large` detents, auto-fired once on launch + manual `calendar.badge.checkmark` toolbar entry. Strict calendar-day rollover; no freeze, no notifications, no analytics (KISS).

Sources: [scout-01](scout/scout-01-codebase-map.md), [researcher-01](research/researcher-01-streak-mechanics.md), [researcher-02](research/researcher-02-checkin-ui.md).

### Phases

| # | Phase | Status | Effort | File |
|---|---|---|---|---|
| 01 | Persistence & Model | done | 1h | [phase-01-persistence-and-model.md](phase-01-persistence-and-model.md) |
| 02 | Streak Logic | done | 1.5h | [phase-02-streak-logic.md](phase-02-streak-logic.md) |
| 03 | AppModel Integration | done | 1h | [phase-03-appmodel-integration.md](phase-03-appmodel-integration.md) |
| 04 | CheckInView | done | 2h | [phase-04-checkin-view.md](phase-04-checkin-view.md) |
| 05 | Home Integration | done | 1h | [phase-05-home-integration.md](phase-05-home-integration.md) |
| 06 | Tests | done | 1.5h | [phase-06-tests.md](phase-06-tests.md) |

**Total: 8h.** Dependency chain is strictly linear (01→02→03→04→05; 06 last). All phases implemented, reviewed, tested green.

### Out of Scope (YAGNI)
Streak-freeze tokens, local notifications, analytics, leaderboard, server validation, "lost streak" recovery screen, hint-powerup day-7 reward, onboarding gate. Each explicitly rejected in researcher-01/researcher-02.

## Resolved Questions
1. **Decision Point → Option B** (additive economy; solve-rewards kept).
2. **First-launch day-1 → Immediate auto-fire** on first launch (hasSeenCheckinSheetToday seeded false).
3. **`streakDays` display → Tier wraps 1..7**, counter persists internally.

## Deviations from original plan (impl)
- **Phase 01**: Added a custom `Progress.init(from:)` using `decodeIfPresent` + `CodingKeys`. The plan claimed synthesized Codable honors property defaults for missing keys — it does NOT. Without this, old users' saved progress would fail to decode and silently reset. Verified by `oldProgressBlobDecodesCheckInFieldsToDefaults` test.
- **Phase 03**: `AppModel.init` now takes `settingsDefaults: UserDefaults` (retained) and derives settings persistence through it (was hardcoded `.standard`) — fixes test isolation + a read/write divergence footgun.
- **Phase 04**: Added an explicit close button (`xmark`) to CheckInView — HIG-recommended for modal sheets + makes UI-test dismissal deterministic.
- **Phase 05**: Reordered auto-fire to present sheet THEN mark seen (closes a background-during-sleep race flagged in code review).
