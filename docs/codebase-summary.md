# Codebase Summary — 4 Pics 1 Word

Folder layout and one-line purpose per key file. Last updated: 2026-06-30.

## Entry point
- `4pics1word/_pics1wordApp.swift` — `@main` `App`; clears `progress.v1` + `settings.v1` on `-uitest-reset` launch arg; hosts `AppRootView`.

## `4pics1word/Views/` — screens
- `AppRootView.swift` — root shell; splash → `NavigationStack`(Home) → `fullScreenCover`(Game) → sheet(Win); daily-check-in sheet at `.medium` detent; auto-fires sheet once/day after splash.
- `HomeView.swift` — title, Play/Continue, level label; toolbar = `CoinCounter` + check-in button (bounce fx when claimable) + settings link.
- `GameView.swift` — main gameplay: header(exit/level/coins), `PictureGrid`, `AnswerSlots`, hint bar (Reveal/Remove/Shuffle), `LetterBank`; owns celebration-wave + wrong-answer haptic drivers.
- `CheckInView.swift` — daily-reward sheet: 3-3-1 grid, claimed-check tiles, jackpot Day-7 horizontal layout, live midnight countdown, coin-fly-to-header animation, jackpot confetti.
- `WinView.swift` — solve sheet: seal icon, revealed word, `+reward` / total, Next Level / Home buttons.
- `ATTExplainerView.swift` — one-shot pre-prompt sheet (value-framed copy) before the system ATT dialog; "Continue" triggers `ATTRequester.requestIfNeeded`.
- `SplashView.swift` — 1.5s launch splash over `splashBackground` image; accessibility-hidden.
- `SettingsView.swift` — Form: appearance (light/dark segmented), haptics toggle, reset progress (confirmation), credits link, version.
- `CreditsView.swift` — `List` of unique photo attributions across all bundled levels (legal).

## `4pics1word/Components/` — reusable views
- `LetterBank.swift` — 6-col `LazyVGrid` of bank tiles; tap → `state.placeTile(id)`.
- `PictureGrid.swift` — 2×2 grid of `PuzzleImage`; tap → `matchedGeometryEffect` zoom within grid bounds; reserves cell shape while zoomed.
- `TileButton.swift` — `TileButtonStyle` (letter tiles; accent fill, press fade).
- `CoinCounter.swift` — coin chip (yellow capsule, `circle.fill` glyph, monospaced digits).
- `AnswerSlots.swift` — answer row; tap filled slot to return tile; `KeyframeAnimator` for solve-wave (scale/rotate/green glow) + wrong-rejection (red glow/shake); reduce-motion skips.
- `PuzzleImage.swift` — loads `<id>_<1-4>.webp` from bundle, `NSCache`-backed, fallback placeholder.
- `ImageZoomOverlay.swift` — zoomed picture overlay (grid-area only), credit pill, tap/a11y-action to dismiss.

## `4pics1word/Game/` — domain logic
- `AppModel.swift` — `@Observable` orchestrator: owns `LevelService`/`ProgressStore`/`Settings`; drives `AppPhase` (home/playing/celebrating/won); solve-reward + persistence + level advance; `checkIn()`; safety-net celebration Task; haptics/appearance wiring.
- `PuzzleState.swift` — `@Observable` single-puzzle engine; `Tile`/bank/slots; place/remove/reveal/remove-hint/shuffle; `wrongAttemptToken` + `isRejecting` deferred clear; `solvedToken` + `onSolved` callback; invariants I5/I6/I7.
- `CheckIn.swift` — static: `rewards = [20,25,30,35,40,50,100]`, streak-day math, `canClaim`, clock-rewind detection (`rewindTolerance = 120s`).
- `Economy.swift` — `HintCost` (reveal 60 / remove 90 / shuffle 0); `Economy.reward(forTier:) = 25 + 5*tier`; `startingCoins = 100`.
- `Feedback.swift` — UIKit haptics (no audio); cached generators; `tap/wrong/warning/win/reward/celebration*`; `enabled` mirrors settings.
- `Settings.swift` — `Codable` prefs (haptics, appearance, lastCheckinSheetDay); `UserDefaults` key `settings.v1`.

## `4pics1word/Data/` — persistence + loading
- `LevelService.swift` — loads `puzzles.json` + `strategy.json` from bundle; filters to puzzles with bundled `.webp` images; `subscript`/`puzzle(byId:)`; `Strategy.tier(for:)`.
- `Models.swift` — `Puzzle`, `PuzzleData`, `Strategy`, `Progress` (level index, coins, solved IDs, streak, lifetime check-ins, anti-rewind watermark, interstitial counter, `lastInterstitialAt`, `hasSeenAttPrompt`).
- `ProgressStore.swift` — `UserDefaults` JSON codec for `Progress`, key `progress.v1`; `load`/`save`/`reset`.
- `PoolFactory.swift` — builds scrambled letter pool (solution + decoys, `poolSize = max(12, len+3)`); seeded by `SplitMix64(puzzle.id.stableSeed)` for determinism.
- `SplitMix64.swift` — `RandomNumberGenerator` impl; `Int.stableSeed` extension.

## `4pics1word/Ads/` — AdMob integration
- `AdsManager.swift` — `@Observable @MainActor` concrete `AdsManaging`; GAD interstitial/rewarded/banner delegate; SDK init → UMP → preload; NPA extra while ATT unauthorized; `topViewController()` helper.
- `AdsManaging.swift` — `@MainActor` protocol seam (`start`/`preloadRewarded`/`showRewarded`/`maybeShowInterstitial`/`bannerReady`) + `RewardGrant` typealias.
- `AdsConfiguration.swift` — ad-unit IDs (Google sample/test IDs — dev only) + `isAdsDisabled` kill-switch (reads `-uitest-reset`).
- `ATTRequester.swift` — `ATTrackingManager` wrapper; `shouldUseNonPersonalizedAds()`; `requestIfNeeded(then:)`.
- `BannerHostView.swift` — `UIViewControllerRepresentable` hosting adaptive `GADBannerView`; `adBanner` a11y id on the host view.

## Tests
- `4pics1wordTests/` — Swift Testing: `CheckInTests`, `PuzzleStateTests`, `PuzzleStateHintTests`, `PuzzleStateWrongAttemptTests`, `PoolFactoryTests`, `AppModelTests`, `AppModelCheckInTests`, `AppModelCelebrationTests`, `AdsTests` (interstitial cadence, reward idempotency, ATT first-solve, Progress backward-compat). `MockAdsManager.swift` is the test double.
- `4pics1wordUITests/` — XCTest: `CheckInUITests`, `ImageZoomUITests`, `SolveFlowUITests`, `AdsUITests` (banner present/absent under kill-switch), launch/launch-tests.

See [system-architecture.md](./system-architecture.md) for runtime flow and [code-standards.md](./code-standards.md) for conventions.
