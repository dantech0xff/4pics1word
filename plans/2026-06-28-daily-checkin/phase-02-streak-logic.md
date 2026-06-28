# Phase 02 — Streak Logic

## Context links
- Plan: [plan.md](plan.md)
- Research: [researcher-01 §1–5](../research/researcher-01-streak-mechanics.md)
- Scout: [scout-01 §Patterns to Match, §Integration 2](../scout/scout-01-codebase-map.md)

## Overview
- **Date:** 2026-06-28
- **Description:** New `Game/CheckIn.swift` — pure `enum` namespace mirroring `Economy.swift`. Day-rollover via `Calendar.startOfDay`, streak computation, reward curve, double-claim + clock-rewind guards.
- **Priority:** P2
- **Impl status:** done
- **Review status:** done

## Key Insights
- Mirror `Economy.swift` exactly: `enum CheckIn { static func ... }`. Pure functions, `@MainActor` default isolation, no state ownership (state lives in `Progress`, mutated by `AppModel`).
- Use **calendar-day delta**, not 24h elapsed (researcher-01 §2). `Calendar.dateComponents([.day], from:to:)` gives `delta`: `0`=same day, `1`=continue, `>1`=break.
- **7-day wrap**: reward tier = `((streakDays - 1) % 7) + 1`. Streak counter climbs past 7 internally (so a 10-day streak still has history) but the *reward* wraps. (Confirms Unresolved Q3 in plan.md.)
- **Rewind guard**: single `Date` compare. If `Date() < progress.lastKnownNow - 120s`, treat as tampering → refuse claim, don't update `lastKnownNow` (so they can't ratchet it down). 120s tolerance absorbs minor NTP drift.
- Timezone-travel "abuse" (claim 23:00 Tokyo, re-claim 00:01 Honolulu) is ≤1/day net and user-friendly — explicitly accepted (researcher-01 §2). Skip pinning a home calendar.

## Requirements
1. `enum CheckIn` with:
   - `static let rewards: [Int] = [20, 25, 30, 35, 40, 50, 100]` (index 0 = day 1).
   - `static func reward(forStreakDay day: Int) -> Int` → `rewards[(day - 1) % 7]`.
   - `static func dayDelta(from last: Date?, to now: Date = Date()) -> Int?` → nil if `last == nil`; else calendar-day delta.
   - `static func canClaim(progress: Progress, now: Date = Date()) -> Bool`.
   - `static func nextStreakDay(progress: Progress, now: Date = Date()) -> Int` → 1 if first/broken, else `progress.streakDays + 1`.
   - `static let rewindTolerance: TimeInterval = 120`.
2. All functions `now: Date = Date()` parameterized → testable with injected dates.
3. No mutation of `Progress` here (pure queries). `AppModel` applies the result.
4. No file prefix needed (`CheckIn.swift`, not `_CheckIn.swift`) — scout §Patterns.

## Architecture
```
CheckIn (enum namespace, pure)
├─ rewards: [Int]                      // [20,25,30,35,40,50,100]
├─ reward(forStreakDay:) -> Int        // wraps via % 7
├─ dayDelta(from:to:) -> Int?          // Calendar.current.startOfDay + dateComponents
├─ canClaim(progress:now:) -> Bool     // delta != 0 AND not rewind-flagged
└─ nextStreakDay(progress:now:) -> Int // 1 | streakDays+1
```

### Reward curve (researcher-01 §1)
```
Day:   1   2   3   4   5   6   7   (8 wraps to 1)
Coins: 20  25  30  35  40  50  100  (20)
```
Weekly total = 300. Day 7 = 5× day 1 (feels "big"), bounded inflation.

### Anti-exploit (researcher-01 §3)
| Threat | Defense |
|---|---|
| Double-claim same day | `canClaim` = `dayDelta != 0` |
| Clock rewind | `canClaim` false if `now < lastKnownNow - 120s` |
| Clock forward | Skip (cost ≤ 1 day's coins, can't block offline) |
| iCloud restore replay | Skip (YAGNI, single-player) |

## Related code files
- `4pics1word/Game/Economy.swift:9` — REFERENCE (style template)
- `4pics1word/Game/CheckIn.swift` — CREATE
- `4pics1word/Data/Models.swift:35` — READ (uses `Progress.lastCheckInDate`, `streakDays`, `lastKnownNow`)

## Implementation Steps
1. Create `4pics1word/Game/CheckIn.swift` (auto-joins target via file-sync group).
2. Implement `enum CheckIn` per Architecture above.
3. `dayDelta`: `Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: last), to: Calendar.current.startOfDay(for: now)).day ?? 0`.
4. `canClaim`: guard `!isRewindSuspected(progress, now)` then `dayDelta(from: progress.lastCheckInDate, to: now) != 0`.
5. `isRewindSuspected`: `progress.lastKnownNow.map { now < $0.addingTimeInterval(-rewindTolerance) } ?? false`.
6. Build.

### Code shape
```swift
import Foundation

enum CheckIn {
    static let rewards: [Int] = [20, 25, 30, 35, 40, 50, 100]
    static let rewindTolerance: TimeInterval = 120

    static func reward(forStreakDay day: Int) -> Int {
        let idx = ((day - 1) % 7 + 7) % 7
        return rewards[idx]
    }

    static func dayDelta(from last: Date?, to now: Date = Date()) -> Int? {
        guard let last else { return nil }
        let cal = Calendar.current
        return cal.dateComponents([.day], from: cal.startOfDay(for: last), to: cal.startOfDay(for: now)).day ?? 0
    }

    static func canClaim(_ progress: Progress, now: Date = Date()) -> Bool {
        if isRewindSuspected(progress, now) { return false }
        return dayDelta(from: progress.lastCheckInDate, to: now) != 0
    }

    static func nextStreakDay(_ progress: Progress, now: Date = Date()) -> Int {
        guard let delta = dayDelta(from: progress.lastCheckInDate, to: now) else { return 1 }
        return delta == 1 ? progress.streakDays + 1 : 1
    }

    private static func isRewindSuspected(_ progress: Progress, now: Date) -> Bool {
        progress.lastKnownNow.map { now < $0.addingTimeInterval(-rewindTolerance) } ?? false
    }
}
```

## Todo list
- [ ] Create `CheckIn.swift`
- [ ] Build passes
- [ ] Spot-check `reward(forStreakDay: 8) == 20`, `(15) == 25` (wrap)

## Success Criteria
- All functions pure (no `@Observable`, no globals mutated).
- Every function accepts `now:` for testability.
- `canClaim` returns false for same-day, true for next-day, false for rewind.

## Risk Assessment
- **Risk:** `Calendar.current` follows device tz → traveler can claim twice in 24h. **Accepted** (researcher-01 §2).
- **Risk:** 120s tolerance too tight for slow NTP. **Impact:** rare false-negative on claim. **Mitigation:** if reported, bump to 300s.
- **Risk:** `%` on negative ints. **Mitigation:** `((x % 7) + 7) % 7` double-wrap in `reward`.

## Security Considerations
Rewind guard is the *only* security logic. It is deliberately weak (single Date compare, no Keychain) because there's no IAP/economy fraud surface worth defending (researcher-01 §3). Do NOT add jailbreak detection, device attestation, or receipt validation.

## Next steps
→ Phase 03 (`AppModel.checkIn()` calls `CheckIn.canClaim` / `nextStreakDay` / `reward` and persists).
