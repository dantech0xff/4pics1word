# Phase 07 — Interstitial AppModel Integration + Reward Grant

## Context links
- Parent plan: `../plan.md`
- Dependency: Phase 02 (Progress fields), Phase 03 (protocol + mock), Phase 05 (AdsManager).
- Brainstorm: §"Recommended architecture" §"Key flows".
- Source: `4pics1word/Game/AppModel.swift` (L128 `nextLevel`, L81 `handleSolved`).

## Overview
- Date: 2026-07-02
- Description: Inject `AdsManaging` into `AppModel`. After WinView dismiss → `nextLevel()`: bump counter, check frequency (every 3rd) + cooldown (≥60s), call `ads.maybeShowInterstitial()` + record timestamp. Reward-grant path: `grantRewardCoins(50)` invoked by `AdsManager.showRewarded` closure — synchronously update `progress.coins` + persist. First-solve → trigger ATT explainer.
- Priority: P1
- Implementation status: pending
- Review status: pending

## Key Insights
- **Single mutation gate** — `progress.coins` mutations ONLY happen via AppModel methods (existing convention; matches `PuzzleState.canMutate`). Reward callback lands here, never directly writes Progress.
- **ATT first-solve trigger** — in `handleSolved` (L81), branch on `!progress.hasSeenAttPrompt`; flip flag synchronously, set `model.shouldShowAttExplainer = true` (observed by AppRootView sheet).
- **Frequency logic** — AppModel owns the math (testable without SDK): `progress.levelsCompletedSinceInterstitial += 1` per `nextLevel`. Show when `levelsCompletedSinceInterstitial >= 3 && (now - lastInterstitialAt ?? .distantPast) ≥ 60`. Reset counter + update timestamp on actual show (mock-asserted).
- **Cooldown** — `lastInterstitialAt` is `Date?`; `distantPast` sentinel avoids optional-unpack dance.
- **Mock replaces real AdsManager in tests** — `AppModel(ads: MockAdsManager())` in new tests; existing 89 tests construct `AppModel()` without `ads` → keep `ads` parameter optional with default `MockAdsManager()` ONLY in DEBUG, or default to a no-op conformer. **Cleaner:** make `ads` a required constructor param and update all 89 tests' construction sites (mechanical).
- **Backward-compat default** — if updating 89 test sites is too churny, supply `ads: AdsManaging = AdsConfiguration.isAdsDisabled ? NoOpAdsManager() : AdsManager()`. Decide Phase 09.

## Requirements
1. `AppModel` holds `let ads: AdsManaging`.
2. `nextLevel()` advances interstitial counter + checks frequency/cooldown + shows ad when eligible.
3. `grantRewardCoins(_ amount: Int)` — adds to `progress.coins`, persists. Called by AdsManager reward closure (Phase 08 wires UI).
4. `handleSolved` first-solve branch sets `hasSeenAttPrompt = true` + observable `shouldShowAttExplainer`.
5. All 89 existing tests still pass (with mock injected).
6. New unit tests cover: counter math, cooldown, first-solve flag.

## Architecture

### `AppModel` modifications
```swift
@Observable
final class AppModel {
    let ads: AdsManaging           // NEW
    var shouldShowAttExplainer: Bool = false   // NEW observable

    init(service: LevelService = .load(),
         store: ProgressStore = .init(),
         settings: Settings? = nil,
         settingsDefaults: UserDefaults = .standard,
         ads: AdsManaging = AdsManager()) {     // NEW
        // … existing init …
        self.ads = ads
    }

    func nextLevel() {
        celebrationTask?.cancel(); celebrationTask = nil
        guard hasNextLevel else { phase = .home; return }

        progress.levelsCompletedSinceInterstitial += 1
        if shouldShowInterstitial {
            progress.levelsCompletedSinceInterstitial = 0
            progress.lastInterstitialAt = Date()
            store.save(progress)
            ads.maybeShowInterstitial()
        }
        startLevel(at: progress.currentLevelIndex)
    }

    private var shouldShowInterstitial: Bool {
        let cooldown: TimeInterval = 60
        let last = progress.lastInterstitialAt ?? .distantPast
        return progress.levelsCompletedSinceInterstitial >= 3 && Date().timeIntervalSince(last) >= cooldown
    }

    func grantRewardCoins(_ amount: Int) {
        progress.coins += amount
        store.save(progress)
    }

    private func handleSolved(_ state: PuzzleState) {
        let tier = service.strategy.tier(for: progress.currentLevelIndex)
        let reward = Economy.reward(forTier: tier)
        progress.coins = state.coins + reward
        progress.solvedIds.insert(state.puzzle.id)
        progress.currentLevelIndex = (progress.currentLevelIndex + 1) % totalLevels
        lastReward = reward
        store.save(progress)

        if !progress.hasSeenAttPrompt {
            progress.hasSeenAttPrompt = true
            store.save(progress)
            shouldShowAttExplainer = true
        }

        phase = .celebrating
        celebrationTask?.cancel()
        celebrationTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2.0))
            guard !Task.isCancelled, let self else { return }
            guard self.phase == .celebrating else { return }
            self.completeSolve()
        }
    }
}
```

### AppRootView ATT explainer sheet (extends `.task` region L32)
```swift
.sheet(isPresented: $model.shouldShowAttExplainer) {
    ATTExplainerView {
        model.shouldShowAttExplainer = false
        ATTRequester.requestIfNeeded { /* re-resolve NPA */ }
    }
}
```
Call `ads.start()` in AppRootView `.task`:
```swift
.task {
    try? await Task.sleep(for: .seconds(1.5))
    withAnimation(.easeInOut(duration: 0.4)) { showSplash = false }
    model.ads.start()   // NEW
    if model.canCheckInToday && !model.hasSeenCheckinSheetToday { … }
}
```

## Implementation Steps
1. Add `ads: AdsManaging` to AppModel.init (default `AdsManager()`).
2. Add `shouldShowAttExplainer: Bool` observable.
3. Modify `nextLevel()` per Architecture.
4. Add `shouldShowInterstitial` computed prop.
5. Add `grantRewardCoins(_:)`.
6. Modify `handleSolved` to flip ATT flag + set `shouldShowAttExplainer`.
7. AppRootView: add `ATTExplainerView` sheet + `ads.start()` in `.task`.
8. Decide test-construction strategy: default `AdsManager()` for production OR explicit `MockAdsManager()` in tests (recommended — see Insights).
9. Update all 89 existing test construction sites if `ads` becomes required-without-default.
10. Build green.
11. Tests green.
12. Commit: `feat(ads): AppModel interstitial cadence + reward grant + ATT trigger [phase-07]`.

## todo list
- [ ] `ads: AdsManaging` property on AppModel
- [ ] `shouldShowAttExplainer` observable
- [ ] `nextLevel()` frequency/cooldown logic
- [ ] `shouldShowInterstitial` computed prop
- [ ] `grantRewardCoins(_:)`
- [ ] `handleSolved` ATT-first-solve branch
- [ ] AppRootView ATT explainer sheet
- [ ] AppRootView `.task` calls `ads.start()`
- [ ] Default-vs-injection decision for tests (documented in commit msg)
- [ ] Update 89 test construction sites (if injecting)
- [ ] Build green
- [ ] Tests green (89 + new — new tests land in Phase 09)
- [ ] Commit

## Success Criteria
- AppModel takes `AdsManaging`; production wires AdsManager, tests wire MockAdsManager.
- `nextLevel` advances counter; shows interstitial on every 3rd w/ ≥60s gap.
- Reward grant persists synchronously.
- First solve sets ATT flag + presents explainer (manual sim).
- Subsequent solves do NOT re-prompt.

## Risk Assessment
| Risk | Mitigation |
|---|---|
| Default `AdsManager()` in init triggers SDK init during unit tests | Inject `MockAdsManager()` explicitly in tests; OR default to `AdsConfiguration.isAdsDisabled ? MockAdsManager() : AdsManager()`. |
| Counter advances but interstitial not ready → silent skip → counter resets anyway | `shouldShowInterstitial` only gates *intent*; `ads.maybeShowInterstitial` self-gates on `interstitial != nil`. Counter reset happens on intent, acceptable (player still gets cadence respite). |
| ATT flag flip on first solve but sheet doesn't present (race with phase change) | `shouldShowAttExplainer` is observable, independent of AppPhase; sheet presents regardless of phase (acceptable; celebratory moment). |
| Race: WinView "Home" path calls `exitToHome` not `nextLevel` → counter never advances | Correct — interstitial only on `nextLevel` per locked decision. |
| Reward grant fires twice if user reopens ad flow mid-callback | `AdsManager.pendingGrant` is single-shot (Phase 05). |

## Security Considerations
None — coin grant is local state mutation, persisted synchronously.

## Next steps
→ Phase 08 (Rewarded UI surfaces) — depends on Phase 07 (calls `model.ads.showRewarded`).
