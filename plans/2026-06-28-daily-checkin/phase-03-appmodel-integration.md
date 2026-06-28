# Phase 03 — AppModel Integration

## Context links
- Plan: [plan.md](plan.md)
- Research: [researcher-01 §5 Edge Cases](../research/researcher-01-streak-mechanics.md)
- Scout: [scout-01 §Integration 3](../scout/scout-01-codebase-map.md)
- Prev: [phase-02-streak-logic.md](phase-02-streak-logic.md)

## Overview
- **Date:** 2026-06-28
- **Description:** Wire `CheckIn` into `AppModel`: `checkIn()` method, `canCheckInToday` derived, `lastCheckInReward` for the view, persist via `store.save`, ensure `resetProgress()` clears state. **Assumes Decision Point Option B (additive).**
- **Priority:** P2
- **Impl status:** done (Decision Point resolved: Option B)
- **Review status:** done

## Key Insights
- `AppModel` is `@Observable` (`AppModel.swift:12`) — adding `@ObservationTracked` stored props is just `var`. View auto-updates.
- All mutations already go through `AppModel` (scout §Architecture). Don't bypass by writing `Progress` directly from a view.
- `handleSolved` (`AppModel.swift:62`) is the *existing* reward path (Option B keeps it). `checkIn()` is a **parallel** path — no shared reward abstraction needed (DRY violation risk: only 2 call sites, different semantics; leave inline).
- Atomicity: `store.save(progress)` is a single `UserDefaults.set` (atomic). No two-phase commit needed.
- `lastReward` pattern already exists for solve rewards (`AppModel.swift:70`) → mirror it as `lastCheckInReward` for the view to drive count-up animation.

## Requirements
1. New `AppModel.checkIn() -> Int?` (returns reward amount or nil if can't claim).
2. New computed `var canCheckInToday: Bool` (delegates to `CheckIn.canClaim(progress)`).
3. New stored `var lastCheckInReward: Int = 0` (drives view's count-up source).
4. `checkIn()`:
   - Guard `CheckIn.canClaim(progress)` else return nil.
   - Compute `day = CheckIn.nextStreakDay(progress)`.
   - Compute `reward = CheckIn.reward(forStreakDay: day)`.
   - `progress.streakDays = day`.
   - `progress.coins += reward`.
   - `progress.lastCheckInDate = Date()`.
   - `progress.lifetimeCheckIns += 1`.
   - `progress.lastKnownNow = Date()` (advance high-water mark).
   - `lastCheckInReward = reward`.
   - `store.save(progress)`.
   - Return reward.
5. On every app foreground/launch: refresh `progress.lastKnownNow = max(now, lastKnownNow)` if not rewind-suspected (so legitimate forward time advances the mark). Do this lazily in `checkIn()` only — KISS, no foreground observer.
6. `resetProgress()` already resets `Progress()` → check-in fields auto-cleared. **No change needed** (verify in Phase 06).
7. **Decision Point Option A (if chosen instead)**: delete `Economy.reward` call + `lastReward` from `handleSolved` (`AppModel.swift:64,70`); adjust solve tests. Skip this if Option B confirmed.

## Architecture
```
AppModel (@Observable)
├─ checkIn() -> Int?              // NEW: applies reward, persists, returns amount
├─ canCheckInToday: Bool          // NEW: computed
├─ lastCheckInReward: Int = 0     // NEW: view reads for count-up
└─ resetProgress()                // unchanged (Progress() resets fields)
```

## Related code files
- `4pics1word/Game/AppModel.swift:13` — MODIFY (add props + method)
- `4pics1word/Game/AppModel.swift:62` — READ (handleSolved, Option B keeps intact)
- `4pics1word/Game/AppModel.swift:108` — READ (resetProgress, no change)
- `4pics1word/Game/CheckIn.swift` — READ (Phase 02 output)
- `4pics1word/Data/ProgressStore.swift:17` — READ (save, unchanged)

## Implementation Steps
1. In `AppModel`, add stored `var lastCheckInReward: Int = 0` near `lastReward` (line 20).
2. Add computed `var canCheckInToday: Bool { CheckIn.canClaim(progress) }` in MARK Derived section (after line 40).
3. Add `func checkIn() -> Int?` in MARK Flow section (after `handleSolved`, ~line 80):
   ```swift
   func checkIn() -> Int? {
       guard CheckIn.canClaim(progress) else { return nil }
       let day = CheckIn.nextStreakDay(progress)
       let reward = CheckIn.reward(forStreakDay: day)
       progress.streakDays = day
       progress.coins += reward
       progress.lastCheckInDate = Date()
       progress.lifetimeCheckIns += 1
       progress.lastKnownNow = Date()
       lastCheckInReward = reward
       store.save(progress)
       return reward
   }
   ```
4. Build.
5. (Option A only, if chosen): edit `handleSolved` to drop reward lines.

## Todo list
- [ ] Decision Point resolved (A or B)
- [ ] Add `lastCheckInReward`, `canCheckInToday`, `checkIn()`
- [ ] Build passes
- [ ] Manual: invoke `checkIn()` twice in same session → second returns nil

## Success Criteria
- `checkIn()` returns positive `Int` on first call of the day, `nil` on repeat.
- `progress.coins` increases by exactly `CheckIn.reward(forStreakDay:)`.
- `store.save` called exactly once per successful `checkIn()`.
- After `resetProgress()`, `canCheckInToday == true` and `progress.streakDays == 0`.

## Risk Assessment
- **Risk:** Rewind guard freezes out legitimate user after tz change. **Impact:** user can't claim until real time catches up to `lastKnownNow`. **Mitigation:** rewind only flags `now < lastKnownNow - 120s`, not equality; forward tz always passes.
- **Risk:** Mid-claim app kill. **Impact:** none — `UserDefaults.set` is atomic (researcher-01 §5).
- **Risk:** Concurrent `checkIn()` calls. **Impact:** none — `@MainActor` isolation serializes; second call sees `lastCheckInDate` updated and returns nil.

## Security Considerations
Rewind guard updated here (`progress.lastKnownNow = Date()` on successful claim). High-water mark only advances on legitimate claim, never on rewind-suspected attempt — prevents ratchet-down attack.

## Next steps
→ Phase 04 (`CheckInView` reads `model.canCheckInToday`, calls `model.checkIn()`, displays `model.lastCheckInReward`).
