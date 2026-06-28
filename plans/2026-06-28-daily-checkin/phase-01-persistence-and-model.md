# Phase 01 — Persistence & Model

## Context links
- Plan: [plan.md](plan.md)
- Research: [researcher-01 §4 Persistence Schema](../research/researcher-01-streak-mechanics.md)
- Scout: [scout-01 §Integration 1](../scout/scout-01-codebase-map.md)

## Overview
- **Date:** 2026-06-28
- **Description:** Extend `Progress` with 4 check-in fields; ensure Codable forward-compat; document migration convention.
- **Priority:** P2
- **Impl status:** done
- **Review status:** done

## Key Insights
- `Progress` is `Codable, Equatable` with **all fields defaulted** (`Models.swift:35-41`). Swift's `JSONDecoder` synthesizes `init(from:)` that fills missing keys with defaults → adding new defaulted fields is a **non-breaking migration**. No key bump (`progress.v1` stays).
- `ProgressStore` (`ProgressStore.swift`) is a thin UserDefaults JSON wrapper — no schema awareness, zero changes needed there.
- Single-blob persistence = atomic writes, no desync risk across coin state vs streak state (researcher-01 §4 table).
- `resetProgress()` in `AppModel.swift:108` already does `progress = Progress()` → new fields auto-reset to defaults. No extra wiring.

## Requirements
1. Add exactly 4 fields to `Progress` (no more — DRY):
   - `lastCheckInDate: Date?` (nil = never claimed)
   - `streakDays: Int = 0` (current streak; wraps tier via modulo in Phase 02, raw counter persists)
   - `lifetimeCheckIns: Int = 0` (stat; cheap to keep, useful later)
   - `lastKnownNow: Date?` (clock-rewind guard, Phase 02 §3)
2. Preserve `Equatable` conformance (auto-synthesized; adding fields is fine).
3. No new file — edit `Models.swift` in place.
4. No `CodingKeys` (synthesis handles forward-compat).

## Architecture
```
Progress (Codable, Equatable)
  currentLevelIndex: Int = 0          // existing
  coins: Int = 100                    // existing
  solvedIds: Set<Int> = []            // existing
+ lastCheckInDate: Date? = nil        // NEW
+ streakDays: Int = 0                 // NEW
+ lifetimeCheckIns: Int = 0           // NEW
+ lastKnownNow: Date? = nil           // NEW
```

## Related code files
- `4pics1word/Data/Models.swift:35` — MODIFY (extend struct)
- `4pics1word/Data/ProgressStore.swift:7` — NO CHANGE (key stays `progress.v1`)
- `4pics1word/Game/AppModel.swift:108` — NO CHANGE (`resetProgress` already re-inits)

## Implementation Steps
1. Open `4pics1word/Data/Models.swift`.
2. In `struct Progress`, after `solvedIds`, add the 4 fields shown in Architecture above.
3. Build: `xcodebuild -project 4pics1word.xcodeproj -scheme 4pics1word -destination 'platform=iOS Simulator,name=iPhone 16' build`.
4. Confirm no errors (synthesized `Codable`/`Equatable` still valid).

### Code shape (no comments in final code)
```swift
struct Progress: Codable, Equatable {
    var currentLevelIndex: Int = 0
    var coins: Int = Progress.startingCoins
    var solvedIds: Set<Int> = []
    var lastCheckInDate: Date?
    var streakDays: Int = 0
    var lifetimeCheckIns: Int = 0
    var lastKnownNow: Date?

    static let startingCoins = 100
}
```

## Todo list
- [ ] Add 4 fields to `Progress`
- [ ] Build passes
- [ ] Existing tests still pass (no behavior change for legacy fields)

## Success Criteria
- App builds clean.
- Existing `Progress()` init still compiles (callers in `AppModel.resetProgress`, `ProgressStore.load` fallback unaffected).
- Decoding a JSON blob saved by the *old* schema (no new keys) yields a valid `Progress` with check-in fields at defaults (manual verify in Phase 06 tests).

## Risk Assessment
- **Risk:** Future non-additive field change. **Mitigation:** convention is to bump key to `progress.v2` and migrate explicitly (already documented in `ProgressStore` key naming).
- **Risk:** `Date?` encoded as `null` vs missing-key ambiguity. **Impact:** none — both decode to `nil` via synthesis.

## Security Considerations
None. `lastKnownNow` is the only security-relevant field (rewind guard) but its *use* is in Phase 02; here it's just storage.

## Next steps
→ Phase 02 (streak logic reads/writes these fields).
