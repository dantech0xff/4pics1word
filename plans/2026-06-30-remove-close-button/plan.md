---
title: "Remove Close button — swipe/tap-outside dismiss only"
description: "Drop the X button from the daily-reward sheet; dismiss only via swipe/tap-outside, gated by claim state. Fixes inverted interactiveDismissDisabled polarity."
status: in_progress
priority: P2
effort: 1.5h
branch: master
tags: [ui, daily-reward, bugfix]
created: 2026-06-30
---

# Plan — Remove Close Button (Daily Reward Sheet)

## Goal
- Remove the `xmark` Close button from the daily-reward sheet header.
- Dismiss path = swipe-down OR tap-outside only (standard iOS sheet).
- Gate: **cannot** dismiss before claiming today; **can** dismiss after.

## Bug discovered (pre-existing, now blocking)
`AppRootView.swift:27` had `.interactiveDismissDisabled(!model.canCheckInToday)` — **inverted**.
- `canCheckInToday == true` (not claimed) → `disabled(false)` → swipe/tap-outside ALLOWED pre-claim ❌
- `canCheckInToday == false` (claimed) → `disabled(true)` → BLOCKED post-claim ❌

The Close button masked it (its own gate `canDismiss = !canCheckInToday` was correct, and tests only exercised the button, never swipe). Removing the button exposes this — must fix.

Correct: `.interactiveDismissDisabled(model.canCheckInToday)` (no negation) — matches `canDismiss` semantics + requirement + `testCloseIsDisabledBeforeClaim` intent.

## Scope
**Modify:**
- `4pics1word/Views/AppRootView.swift` — fix gate polarity (line 27); drop `onDismiss` closure (line 24).
- `4pics1word/Views/CheckInView.swift` — remove Close button; remove dead `onDismiss`/`canDismiss`/`attemptClose`; re-center header.
- `4pics1wordUITests/CheckInUITests.swift` — replace Close-button tests with swipe-down tests.

**Do NOT touch:** `CheckIn.swift`, `AppModel.swift`, `Feedback.swift`, `project.pbxproj`. (Note: `Feedback.warning()` becomes unused after removing `attemptClose` — left in `Feedback.swift` as a library fn; out of scope.)

## Changes
1. **AppRootView.swift:27** `!model.canCheckInToday` → `model.canCheckInToday`.
2. **AppRootView.swift:24** `CheckInView(model: model) { showCheckinSheet = false }` → `CheckInView(model: model)`.
3. **CheckInView.swift** — drop `let onDismiss`, `canDismiss`, `attemptClose`; rewrite `header` as centered `VStack` (title + counter), keep header-counter frame reader + id.
4. **Tests** — rename `testCloseIsDisabledBeforeClaim` → `testSheetNotDismissableBeforeClaim` (swipeDown no-op pre-claim); rewrite `testToolbarButtonReopensSheetAfterDismiss` to dismiss via swipeDown post-claim.

## Success criteria
- No `xmark`/Close button in the sheet.
- Pre-claim: swipeDown + tap-outside cannot dismiss (sheet persists).
- Post-claim: swipeDown (and tap-outside) dismiss the sheet.
- `xcodebuild build` + unit + UI tests green on iPhone 17 sim.
- `onDismiss`/`canDismiss`/`attemptClose` gone (grep confirms no refs).

## Risks
| Risk | Mitigation |
|---|---|
| XCTest swipeDown doesn't dismiss `.medium` sheet reliably | Standard pattern; gate now correct. Fallback: predicate-wait on `exists==false`. |
| Centered header shifts header-counter frame (coin-fly anchor) | Anchor is on the counter HStack; centering doesn't break it (verified by build + existing fly logic). |
| User can't discover dismiss w/o button | Drag indicator (`.presentationDragIndicator(.visible)`) is the affordance; iOS convention. |

## Out of scope (YAGNI)
- Custom overlay for iPad hard-lock.
- "Are you sure you want to leave?" pre-claim dialog (block is enough).
- Removing now-unused `Feedback.warning()` (in game logic file — don't touch).
