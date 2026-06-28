# Daily Check-In (Streak Rewards) — Research

Scope: coin economy, no shop/IAP. Check-in becomes PRIMARY coin source. Existing `Progress` (Codable, all fields defaulted) lives in `UserDefaults["progress.v1"]` via `ProgressStore`.

## 1. Streak Reward Curves

| Game | Curve shape | Notes |
|---|---|---|
| **Duolingo** | Streak is a *counter* (no coin payout), resets to 0 on miss; "Streak Freeze" ($ shop) forgives 1 day. | Engagement via pride/loss-aversion, not payout. |
| **Wordle** | 1/day hard cap; streak = stat only, no reward. | Strict calendar-day rule, no economy. |
| **Casual puzzle** (Wordscapes, Candy Crush daily wheel, Toon Blast) | **7-day loop**, escalating, day 7 = ~3x daily avg "chest", then reset to day 1. | Proven retention pattern; predictable economy. |

**Recommended for 4pics1word** (check-in = primary coin source; `Progress.startingCoins=100` baseline):

```
Day:   1   2   3   4   5   6   7
Coins: 20  25  30  35  40  50  100
```

- Weekly total = **300 coins**; daily avg ≈ 43. Day 7 = 5x day 1 (felt "big"), still bounded.
- **Loop at day 7**: day 8 reward = day 1 again (streak counter keeps climbing, reward tier wraps). Predictable, simpler than 30-day curve, no runaway inflation.
- Reject 30-day curve: payoff too far for casual word players; high churn before day 7.

## 2. Day-Rollover Handling

Use `Foundation.Calendar` strictly by calendar-day, not 24h elapsed time.

```swift
let cal   = Calendar.current
let today = cal.startOfDay(for: Date())               // midnight-local Date
let delta = cal.dateComponents([.day], from: lastStart, to: today).day ?? 0
// delta == 0 → already claimed today; 1 → continue streak; >1 → break
```

Refs:
- `Calendar.startOfDay(for:)` — https://developer.apple.com/documentation/foundation/calendar/startOfDay(for:)
- `Calendar.dateComponents(_:from:to:)` — https://developer.apple.com/documentation/foundation/calendar/datecomponents(_:from:to:)

**Timezone changes**: `Calendar.current` follows device tz. Traveler who claimed at 23:00 in Tokyo can re-claim at 00:00 in Honolulu — acceptable abuse (≤1/day net, user-friendly). Pinning a "home calendar" on first launch is over-engineering for a no-IAP game. **Skip (YAGNI).**

**Missing days — strict vs grace**: Use **strict calendar-day** (`delta==1` continues, `delta>1` resets). Note this is *already* lenient: claim 23:59, re-claim 00:01 → 2 streak days in 2 min. No 48h grace window needed.

**Device clock tampering**: see §3.

## 3. Anti-Exploit

| Threat | Worth defending? | How |
|---|---|---|
| **Double-claim same day** | **Yes** (trivial) | Store `lastCheckInDate`; refuse if `startOfDay(today) <= startOfDay(last)`. |
| **Clock rewind** (set phone back to yesterday to re-claim) | **Yes** (cheap) | Persist `lastKnownNow: Date`; if `Date() < lastKnownNow - tolerance`, flag/skip. Single Date compare. |
| **Clock forward** (skip to tomorrow) | No (no server) | Cannot fully block offline. Cost: at most 1 extra day's coins. Ignore. |
| **iCloud backup restore replay** | No | Defending requires Keychain (not restored by iCloud) as high-water mark. For a no-IAP single-player game, abuse impact is trivial. **Skip (YAGNI).** |
| **Jailbreak / plist edit** | No | Single-player, no economy to protect beyond own save. Skip. |

Explicitly **do NOT** add: server validation, receipt validation, jailbreak detection, device attestation. No IAP → no fraud surface worth the complexity (KISS).

## 4. Persistence Schema

**Recommendation: extend existing `Progress` struct.** All current fields have defaults → `JSONDecoder` decodes old payloads with new keys absent, filling defaults. Free non-breaking migration; no key bump needed.

```swift
struct Progress: Codable, Equatable {
    var currentLevelIndex: Int = 0
    var coins: Int = Progress.startingCoins
    var solvedIds: Set<Int> = []
    // NEW
    var lastCheckInDate: Date?     // nil = never
    var streakDays: Int = 0        // current streak (0 or 1..7, wraps)
    var lifetimeCheckIns: Int = 0  // stat / analytics
    var lastKnownNow: Date?        // rewind guard (§3)
    static let startingCoins = 100
}
```

**Extend vs. separate `CheckInStore` — pros/cons**:

| | Extend `Progress` (recommended) | New `CheckInStore` |
|---|---|---|
| Migration | Free (defaulted fields) | None needed |
| Save plumbing | Reuse `ProgressStore.save` | Duplicate load/save |
| Atomicity | Single blob, one write | Two stores, desync risk |
| Separation of concerns | Mixed | Cleaner |
| Testability | Existing tests extend | New test surface |

Winner: extend. KISS + DRY. Only split if check-in grows server-sync later.

If a non-additive change ever lands later, bump key to `"progress.v2"` and migrate explicitly (the `.v1` suffix in `ProgressStore` already signals this convention).

## 5. Edge Cases

| Case | Behavior |
|---|---|
| **First-ever launch** (`lastCheckInDate == nil`) | Show check-in CTA; on claim → `streakDays=1`, pay day-1 reward (20). |
| **Returning after 30+ days** (`delta > 1`) | Reset `streakDays = 0` *then* treat as fresh claim → streak 1, day-1 reward. `lifetimeCheckIns` keeps climbing. |
| **Gap of exactly 1 day** (`delta == 1`) | Continue streak: `streakDays = min(streakDays + 1, 7)`; pay tier for new day. No grace needed (calendar rule already forgiving). |
| **Week-cap reset** | At day 7 claim, next eligible day pays **day-1 reward again** but `streakDays` counter continues (or wraps to 1 — pick one; recommend counter climbs, tier wraps). |
| **Claim then app killed mid-save** | `ProgressStore.save` is a single `UserDefaults.set` (atomic by design). Safe. Ref: https://developer.apple.com/documentation/foundation/userdefaults |
| **iCloud restore of older save** | Older `lastCheckInDate` may permit re-claim — accepted (§3). |

## Unresolved Questions

1. Auto-claim on app open, or require explicit button tap? (Tap = stronger engagement signal.)
2. Streak-freeze / make-up token for missed days? (Recommend **no** — no soft currency exists to buy one; KISS.)
3. Day-7 payout = coins only, or coins + hint power-up? (Current model has no hint item; coins only is simplest.)
4. Gate puzzle play behind check-in, or pure optional bonus? (Recommend optional — don't frustrate.)
5. Local notification reminder to sustain streak? (Needs permission request flow; separate scope.)
6. Should `streakDays` display as raw count or as 1–7 tier? (UX decision.)

## Recommendation

Ship a **7-day loop curve (20/25/30/35/40/50/100 coins, week total 300)** with strict `Calendar.startOfDay` day-delta logic (`delta==1` continue, `>1` reset, `==0` refuse), persisted by **adding four fields (`lastCheckInDate`, `streakDays`, `lifetimeCheckIns`, `lastKnownNow`) directly to the existing `Progress` Codable struct** — no key bump, no new store. Defend only same-day double-claim and clock-rewind; explicitly skip iCloud-restore and clock-forward defenses (YAGNI for a no-IAP single-player game). On day 8+ the streak counter keeps climbing but the reward tier wraps back to day-1, keeping the economy bounded and predictable.
