# Phase 05 — Home Integration

## Context links
- Plan: [plan.md](plan.md)
- Research: [researcher-02 §5 Entry points & frequency](../research/researcher-02-checkin-ui.md)
- Scout: [scout-01 §Navigation/UI Entry Points](../scout/scout-01-codebase-map.md)
- Prev: [phase-04-checkin-view.md](phase-04-checkin-view.md)

## Overview
- **Date:** 2026-06-28
- **Description:** Auto-present `CheckInView` once per day on launch (gated by `canCheckInToday && !hasSeenSheetToday`) + persistent `calendar.badge.checkmark` toolbar button in `HomeView`. Wire sheet binding through `AppRootView`.
- **Priority:** P2
- **Impl status:** done
- **Review status:** done

## Key Insights
- **Hybrid entry** wins (researcher-02 §5): auto-popup lifts D7 retention (Duolingo A/B), manual button gives recovery path if dismissed too fast. Auto-only or manual-only both lose.
- **Auto-popup must NOT fire mid-game** — only on Home (`phase == .home`). Gate in `AppRootView.task` after splash dismiss.
- **Once-per-day popup** needs a separate ephemeral flag (`hasSeenCheckinSheetToday`), NOT `lastCheckInDate` — user may dismiss without claiming; manual button must still work. Persist this flag in `Settings` (already a UserDefaults blob) keyed by calendar day so it auto-resets overnight.
- **0.4s delay** after splash dismiss so game state settles (researcher-02 §5). Avoids feeling like an ad.
- **Toolbar button**: place next to existing `gearshape` in `HomeView.toolbar` (`HomeView.swift:21`). Same `Image(systemName: "calendar.badge.checkmark")`, tinted accent if `canCheckInToday`.
- **Sheet binding**: mirror existing `showWin` pattern in `AppRootView.swift:66` — derive `Binding<Bool>` from a `@State` flag on `AppRootView` (not on `AppModel`, since it's purely UI-presentation state).
- Never `.fullScreenCover` on launch (researcher-02 §5).

## Requirements
1. `Settings` gains `var lastCheckinSheetDay: String?` (ISO day string `yyyy-MM-dd`) — ephemeral popup-gate. NOT in `Progress` (not economy state).
2. `AppModel.hasSeenCheckinSheetToday: Bool` computed (compares `settings.lastCheckinSheetDay` to today's ISO day).
3. `AppModel.markCheckinSheetSeen()` sets `settings.lastCheckinSheetDay = today` + `settings.save()`.
4. `HomeView.toolbar`: add `calendar.badge.checkmark` button toggling a `@Binding var showCheckin: Bool`.
5. `AppRootView`: `@State private var showCheckinSheet = false`; `.sheet(isPresented:)` presenting `CheckInView`.
6. `AppRootView.task` (after splash): if `model.canCheckInToday && !model.hasSeenCheckinSheetToday` → `try? await Task.sleep(for: .seconds(0.4))` → `showCheckinSheet = true; model.markCheckinSheetSeen()`.
7. Toolbar button always visible (lets user preview tomorrow's reward even after claiming today).
8. Sheet `onDismiss`: no-op (state already persisted).

## Architecture
```
AppRootView
├─ @State showCheckinSheet: Bool
├─ navigationStack
│   └─ HomeView(model, showCheckin: $showCheckinSheet)
│       └─ toolbar: [CoinCounter] [calendar.badge.checkmark] [gearshape]
└─ .sheet(isPresented: $showCheckinSheet) { CheckInView(model) { showCheckinSheet = false } }

AppModel
├─ hasSeenCheckinSheetToday: Bool      // NEW computed
└─ markCheckinSheetSeen()              // NEW
```

### Day-string format
`ISO8601DateFormatter().string(from: Date())` truncated to `yyyy-MM-dd` (calendar-day stable). Simpler than storing a `Date` + comparing `startOfDay` (avoids tz edge cases on the *popup gate* — distinct from the streak logic which uses `Calendar`).

## Related code files
- `4pics1word/Views/AppRootView.swift:9` — MODIFY (sheet + auto-fire)
- `4pics1word/Views/HomeView.swift:21` — MODIFY (toolbar button)
- `4pics1word/Game/AppModel.swift:36` — MODIFY (add hasSeen/markSeen)
- `4pics1word/Data/Models.swift` or `Settings` location — MODIFY (add `lastCheckinSheetDay`)
- `4pics1word/Views/CheckInView.swift` — READ (Phase 04 output)

## Implementation Steps
1. Locate `Settings` struct (likely `Data/Settings.swift` or similar — confirm at impl time). Add `var lastCheckinSheetDay: String?` with default nil.
2. In `AppModel`, add:
   ```swift
   private var todayKey: String {
       ISO8601DateFormatter().string(from: Date()).prefix(10).description
   }
   var hasSeenCheckinSheetToday: Bool { settings.lastCheckinSheetDay == todayKey }
   func markCheckinSheetSeen() {
       settings.lastCheckinSheetDay = todayKey
       settings.save()
   }
   ```
3. In `HomeView`, change signature to `init(model:, showCheckin: Binding<Bool>)` (or add `@Binding var showCheckin: Bool`).
4. In `HomeView.toolbar`, between `CoinCounter` spacer and gear, add:
   ```swift
   Button { showCheckin = true } label: {
       Image(systemName: "calendar.badge.checkmark")
           .font(.title2)
           .padding(8)
           .symbolEffect(.bounce, options: .repeat(1), isActive: model.canCheckInToday)
   }
   .accessibilityLabel(model.canCheckInToday ? "Daily check-in, reward available" : "Daily check-in")
   ```
5. In `AppRootView`:
   - Add `@State private var showCheckinSheet = false`.
   - Pass `showCheckin: $showCheckinSheet` to `HomeView`.
   - Add `.sheet(isPresented: $showCheckinSheet) { CheckInView(model: model) { showCheckinSheet = false } }` on `navigationStack`.
   - In existing `.task` (after splash dismiss `showSplash = false`), append:
     ```swift
     if model.canCheckInToday && !model.hasSeenCheckinSheetToday {
         try? await Task.sleep(for: .seconds(0.4))
         model.markCheckinSheetSeen()
         showCheckinSheet = true
     }
     ```
6. Build.

## Todo list
- [ ] `Settings.lastCheckinSheetDay` added
- [ ] `AppModel.hasSeenCheckinSheetToday` + `markCheckinSheetSeen()`
- [ ] `HomeView` toolbar button
- [ ] `AppRootView` sheet binding + auto-fire task
- [ ] Manual: launch → sheet appears after 0.4s; dismiss → relaunch same day → no auto-popup; toolbar still opens sheet

## Success Criteria
- First launch of a new calendar day: sheet auto-presents after ~0.4s, once.
- Same-day relaunch: no auto-popup; toolbar button still works.
- After claiming: toolbar icon loses bounce animation; button still opens sheet in "come back tomorrow" state.
- Day rollover (change simulator clock): next launch auto-fires again.
- No auto-popup during `.playing`/`.celebrating`/`.won` phases.

## Risk Assessment
- **Risk:** Auto-popup fires during gameplay if app launched mid-level. **Mitigation:** gate in `.task` which only runs when `navigationStack` appears (= Home visible); `fullScreenCover` for game is layered above and its own `.task` doesn't touch this.
- **Risk:** `todayKey` truncation off-by-one across tz. **Impact:** popup may show twice if tz changes same day. **Accepted** — popup gate is non-economy; worst case is mild annoyance.
- **Risk:** Sheet + game fullScreenCover race on launch. **Mitigation:** 0.4s delay + Home-only gate.
- **Risk:** iOS state restoration re-fires `.task`. **Mitigation:** `markCheckinSheetSeen()` is idempotent; `hasSeenCheckinSheetToday` check prevents re-show.

## Security Considerations
None. Popup gate is UX-only; not security-sensitive. Bypassing it (editing UserDefaults) only causes popup to appear or not — no economy impact.

## Next steps
→ Phase 06 (tests cover logic in 02/03 + UI test for sheet presentation/claim).
