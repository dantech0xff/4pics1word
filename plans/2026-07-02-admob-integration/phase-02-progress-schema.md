# Phase 02 — Progress + Settings Schema (backward-compat)

## Context links
- Parent plan: `../plan.md`
- Dependency: none (parallel-safe with Phase 03).
- Brainstorm: §"Recommended architecture".
- Source: `4pics1word/Data/Models.swift` (L35–62 `Progress`), `4pics1word/Game/Settings.swift`.

## Overview
- Date: 2026-07-02
- Description: Add interstitial-frequency + ATT-prompt-tracking fields to `Progress`; keep backward-compat via custom `init(from:)` decode. No behavior change yet (fields default to safe values; no callers).
- Priority: P1
- Implementation status: pending
- Review status: pending

## Key Insights
- **`Progress` uses an explicit `CodingKeys` enum + manual `init(from:)`** (`Models.swift:46–62`). New fields require BOTH: add to enum + add `decodeIfPresent` in init. Default values ensure old `progress.v1` JSON decodes cleanly.
- **`Progress.startingCoins` already exists** at L44 — pattern reference.
- **No version bump** needed (`progress.v1` key stays). Additive fields with defaults are safe.
- **Settings unchanged.** ATT prompt flag lives in `Progress`, not Settings — it's progress-state, not user preference (user does NOT get to toggle ATT from a settings switch; ATT is a one-way OS-level decision).
- **MainActor default** — these are plain `Codable` structs, no actor concerns.

## Requirements
1. `Progress` gains `levelsCompletedSinceInterstitial: Int = 0`, `lastInterstitialAt: Date? = nil`, `hasSeenAttPrompt: Bool = false`.
2. Backward-compat: decode old `progress.v1` JSON without those keys → defaults applied.
3. `Equatable` still synthesizes correctly (struct is still value type).
4. All 89 unit tests pass unchanged (no caller changes).

## Architecture

### `Progress` additions (`4pics1word/Data/Models.swift`)
```swift
struct Progress: Codable, Equatable {
    // … existing fields …
    var levelsCompletedSinceInterstitial: Int = 0
    var lastInterstitialAt: Date?
    var hasSeenAttPrompt: Bool = false

    private enum CodingKeys: String, CodingKey {
        case currentLevelIndex, coins, solvedIds
        case lastCheckInDate, streakDays, lifetimeCheckIns, lastKnownNow
        case levelsCompletedSinceInterstitial, lastInterstitialAt, hasSeenAttPrompt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // … existing decodes …
        levelsCompletedSinceInterstitial = try c.decodeIfPresent(Int.self, forKey: .levelsCompletedSinceInterstitial) ?? 0
        lastInterstitialAt = try c.decodeIfPresent(Date.self, forKey: .lastInterstitialAt)
        hasSeenAttPrompt = try c.decodeIfPresent(Bool.self, forKey: .hasSeenAttPrompt) ?? false
    }
}
```

## Implementation Steps
1. Add 3 fields with defaults to `Progress`.
2. Add 3 cases to `CodingKeys` enum.
3. Add 3 `decodeIfPresent` lines to `init(from:)`.
4. Build green.
5. Run tests — 89/89 unchanged.
6. Manual sanity: `xcrun simctl spawn booted defaults read -g progress.v1` after a launch, decode in playground to confirm JSON shape (optional).
7. Commit: `feat(ads): extend Progress with interstitial/ATT fields [phase-02]`.

## todo list
- [ ] Add 3 fields to `Progress`
- [ ] Add 3 cases to `CodingKeys`
- [ ] Add 3 `decodeIfPresent` lines
- [ ] Build green
- [ ] Tests 89/89
- [ ] Commit

## Success Criteria
- Old `progress.v1` JSON (pre-existing users) decodes without error.
- New fields default correctly on fresh install.
- No test regressions.

## Risk Assessment
| Risk | Mitigation |
|---|---|
| Forget `CodingKeys` enum update → encode silently drops new fields on save | Add round-trip unit test in Phase 09. |
| Forget `decodeIfPresent` → old JSON throws `keyNotFound` | Add backward-compat test in Phase 09 (decode a JSON blob without the new keys). |
| Field name collides with future schema | Names are specific enough (`levelsCompletedSinceInterstitial` vs `currentLevelIndex`). Acceptable. |

## Security Considerations
None — local-only state.

## Next steps
→ Phase 03 (AdsConfiguration + AdsManaging protocol + Mock) — parallel-safe.
