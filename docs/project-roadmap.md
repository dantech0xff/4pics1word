# Project Roadmap — 4 Pics 1 Word

Status as of 2026-06-30. Derived from `git log --oneline` and `plans/`. Last updated: 2026-06-30.

## Shipped (committed)
- **AdMob integration (banner / interstitial / rewarded)** — GoogleMobileAds 11.x via SPM (app target only); `AdsManaging` protocol + `AdsManager` (`@Observable @MainActor`); HomeView adaptive banner; interstitial every 3rd level-complete (≥60s cooldown); rewarded +50 coins (HomeView button + hint-insufficient alert); ATT prompt after first solve; UMP consent; `PrivacyInfo.xcprivacy`; `-uitest-reset` kill-switch. **⚠️ Submit-blocked**: uses Google sample/test ad IDs (no AdMob account); swap to real IDs in `Info.plist` + `AdsConfiguration` before App Store submission.
- **MVP** — gameplay loop, letter bank, answer slots, hints, economy, level progression (commit `2026-06-28-mvp`).
- **Tap-zoom image viewer** — hero-zoom within grid area, photo credits, dismiss (feat `26659c8`, test `404d088`).
- **Seamless level loop** — hide progress count, wrap-around, appearance persistence (`1a2b715`, test `6a31082`).
- **Appearance toggle** — explicit dark/light setting (`44c684c`).
- **Correct-word celebration** — deferred `.won` via `AppPhase.celebrating` + `solvedToken`; cached haptics; per-tile wave driver (`f7b938a`, `7c671c1`, `60c00e0`, test `0a17345`).
- **Wrong-answer rejection** — deferred clear via `isRejecting` + `clearWrongAttempt`; per-tile red glow + shake (`0c69c23`, `0b7b79a`, test `fa4ce71`).
- **Daily check-in streak** — logic + persistence + AppModel wiring (`2941c97`); sheet + Home toolbar + launch auto-fire (`1d57d95`, test `1d029e8`).
- **Daily-reward sheet redesign** — dismiss gate, two-row grid, enriched tiles (`f05d74c`, test `2b61c0c`).
- **Daily-reward sheet revamp (latest)** — 3-3-1 grid + full-width Day-7 jackpot, claimed = checkmark-only, live midnight countdown via `TimelineView` (`88efd49`, test in `39bbbcd`). Close-button removal (plan `2026-06-30-remove-close-button`) absorbed into this rewrite — sheet now dismisses via swipe/tap-outside only, gated by claim state.

## In progress / planned (uncommitted plan dirs)
- `plans/2026-06-29-daily-reward-sheet-refactor/` — phase docs (lock detent, uniform grid, cell polish, claim animation, tests/a11y). Most landed via the revamp; any unmerged phase polish is residual.
- `plans/2026-06-30-daily-reward-sheet-revamp/` — `status: completed` in plan.md; shipped via `88efd49`.

## Backlog ideas (open / YAGNI-deferred)
- **VoiceOver countdown cadence** — static label w/ coarse "in N hours M minutes" vs per-tick `updatesFrequently` trait (revamp open Q1).
- **iPad jackpot width cap** — verify horizontal Day-7 layout doesn't stretch absurdly on regular size class (revamp open Q2; currently accepted as-is).
- **AX2 single-line fit** — countdown at `.accessibility2` may need `.lineLimit(1)` + `.minimumScaleFactor(0.8)` (revamp open Q3).
- **Mystery tile** — daily-reward tile variant (revamp out-of-scope).
- **Streak-protect states** — freeze/skip-a-day mechanics (revamp out-of-scope).
- **`symbolEffect(.bounce)` on `gift.fill`** — deferred flourish.
- **Countdown on today-tile pill** — currently action-section only.
- **Localisation** — all copy is English hard-coded; no `Localizable.strings`.
- **App Store / CI setup** — no archive/upload pipeline, no CI runner, no Fastlane (see [deployment-guide.md](./deployment-guide.md)).
- **`Feedback.warning()`** — now unused after close-button removal; consider removal or new caller.

## Commit cadence
Feature work follows `docs(plan)` (plan/research/scout) → `feat(...)` (impl) → `test(...)` (coverage) trio. Recent velocity: ~3-4 commits/feature across late June 2026.
