# Phase 05 — Verification Report

**Date:** 2026-06-29
**Simulator:** iPhone 17, iOS 26.5 (no iPhone 16 / iPhone SE image installed — see Open Qs)
**Toolchain:** Xcode 26.6

## Automated results

| Check | Result |
|---|---|
| `xcodebuild build-for-testing` (app + unit + UI targets) | **TEST BUILD SUCCEEDED** |
| Unit tests (`4pics1wordTests`, incl. `CheckInTests`, `AppModelCheckInTests`) | **ALL PASSED** (logic untouched — scope discipline confirmed) |
| UI tests (`CheckInUITests`, 7 tests incl. 2 new) | **7/7 PASSED** |

### New UI tests
- `testProgressDotsRowExists` — finds the dots row via label predicate ("N of 7"), asserts fresh state reads "0 of 7". PASS.
- `testJackpotDayUsesGiftIcon` — finds the D7 cell via label predicate ("jackpot"), asserts label contains "jackpot" + "100". PASS.

### Key finding: XCTest query strategy
SwiftUI custom `.accessibilityElement(children: .ignore)` containers in this iOS 26.5 setup do **not** reliably expose their `.accessibilityIdentifier` to XCTest's identifier-based queries (`app.otherElements[id]`, `app.staticTexts[id]`, `descendants(.any).matching(identifier:)` all returned false). Native elements (Button/Text) query normally by label. **Fix:** new tests use predicate-based **label** matching (`NSPredicate(format:"label CONTAINS %@")` on `descendants(.any)`) — type- and identifier-agnostic. `.accessibilityIdentifier`s remain in the View code for tooling/debugging even though not asserted.

### Non-expand sheet assertion
Per plan default (YAGNI; XCTest cannot directly query detents and frame-height checks are fragile), no automated non-expand assertion. Manual gate below.

## Manual audits — require human verification (CLI cannot run these)

| Audit | Status | Notes |
|---|---|---|
| VoiceOver label sweep (7 cells + "claim in N days") | **PENDING USER** | Labels implemented (`a11yLabel`: claimed/today/locked + "claim in N days" via `todayDay`); verify audibly. |
| Reduce Motion (no fly/shimmer/confetti; counter crossfade) | **PENDING USER** | `reduceMotion` gates fly (`spawnFlyingCoin` not called), shimmer (`shimmerOverlay`), confetti; reduce branch crossfades counter. |
| Reduce Transparency (solid material fallbacks) | **PENDING USER** | `lockChipBackground` swaps `.ultraThinMaterial`→`Color.secondary.opacity(0.55)`; `backgroundView` already had fallback. |
| Dynamic Type `.accessibility2` (no overflow) | **PENDING USER** | Cap set (`...accessibility2`); verify 4-up row at AX2. |
| iPad sim (form-sheet acknowledged) | **PENDING USER** | `.presentationDetents([.medium])` ignored on regular size class — expected; no hard lock API. |
| Sim Daltonism (claimed ✓ vs locked 🔒) | **PENDING USER** | State carried by icon shape, not hue. |
| Drag-up non-expand (iPhone) | **PENDING USER** | Single `.medium` detent = no snap target. |
| iPhone SE (375pt) fit | **BLOCKED** | No SE simulator installed; defer to user. `cellHeight=96` default; fallback `.fraction(0.6)` noted if cramped. |

## Deviations from plan (honesty log)
1. **Today tile tap-to-claim (F6)** — implemented as planned: today tile is `.isButton` + `onTapGesture` → `claimTapped()`. Other tiles `.isStaticText`. Verified non-conflicting with the primary "Claim N coins" button (distinct labels); no double-claim (state flips after first claim).
2. **"claim in N days" arithmetic** — implemented via passed-in `todayDay` (1-based), computing `day - todayDay` only for locked tiles strictly after today. When already-claimed-today (`todayDay == nil`) or across week rollover, falls back to plain "locked" to avoid misleading counts. Robust to streak reset.
3. **Coin fly approach** — used Approach A (transient overlay via a single `CoinFramePreferenceKey` carrying `todayCell` + `headerCounter` anchors), not two separate keys. Spring 0.5/0.85 from→to with opacity fade; counter ticks at +400ms to sync. Needs visual polish confirmation (see Open Qs).
4. **`claimTapped(previewedReward:)` → `claimTapped()`** — removed the unused parameter (was vestigial); jackpot detection now via `todayIndex == rewards.count-1` captured before `checkIn()`.

## Open questions (carry-forward)
1. **Coin fly visual polish** — frame math implemented and compiles; precise arc/landing needs interactive sim eyeballing (CLI can't view animation). If janky, tune spring response/damping or fall back to spring-only (drop fly).
2. **iPhone SE fit** — no SE sim available locally; user to verify 4+3 grid + dots + button fit `.medium` at 375pt. If cramped: reduce `cellHeight` 96→84 or switch detent to `.fraction(0.6)`.
3. **Confetti scope** — D7-only now (`if claimingJackpot { celebrate = true }`). Confirm feels right vs everyday.
4. **Identifier propagation** — custom-element identifiers not XCTest-visible here; if future tests need id-based queries on tiles/dots, investigate (possibly an iOS 26.5 regression). Label-based queries are the reliable path.
