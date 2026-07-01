import Testing
import Foundation
@testable import _pics1word

// MARK: - Local helpers

private func placeSolutionChar(_ state: PuzzleState, _ c: Character) {
    guard let tile = state.bankTiles.first(where: { $0.character == c }) else {
        Issue.record("No bank tile for \(c)")
        return
    }
    state.placeTile(tile.id)
}

// MARK: - AdsManager-backed AppModel logic (frequency, cooldown, reward, ATT)

@MainActor @Suite(.serialized)
struct AdsTests {
    /// Each model gets a UNIQUE UserDefaults suite so persisted progress fields
    /// (interstitial counter, lastInterstitialAt, hasSeenAttPrompt) never leak across tests
    /// or from the shared `UserDefaults.standard` that other AppModel tests pollute.
    private func makeModel(mock: MockAdsManager) -> AppModel {
        let defaults = UserDefaults(suiteName: "AdsTests.\(UUID().uuidString)")!
        return AppModel(store: ProgressStore(defaults: defaults), settingsDefaults: defaults, ads: mock)
    }

    // MARK: Interstitial cadence

    @Test
    func interstitial_shows_on_third_completion() {
        let mock = MockAdsManager()
        let model = makeModel(mock: mock)
        model.nextLevel()
        model.nextLevel()
        model.nextLevel()
        #expect(mock.maybeShowInterstitialCallCount == 1, "Interstitial fires on every 3rd completion")
        #expect(model.progress.levelsCompletedSinceInterstitial == 0, "Counter resets after showing")
        #expect(model.progress.lastInterstitialAt != nil, "Last-show timestamp recorded")
    }

    @Test
    func interstitial_suppressed_by_cooldown() {
        let mock = MockAdsManager()
        let model = makeModel(mock: mock)
        model.progress.lastInterstitialAt = Date()              // just shown — within 60s cooldown
        model.progress.levelsCompletedSinceInterstitial = 2
        model.nextLevel()                                       // counter -> 3, but cooldown blocks
        #expect(mock.maybeShowInterstitialCallCount == 0, "Cooldown suppresses show")
        #expect(model.progress.levelsCompletedSinceInterstitial == 3, "Counter advances but is not reset")
    }

    @Test
    func interstitial_shows_after_cooldown_elapses() {
        let mock = MockAdsManager()
        let model = makeModel(mock: mock)
        model.progress.lastInterstitialAt = Date().addingTimeInterval(-120)   // > 60s ago
        model.progress.levelsCompletedSinceInterstitial = 2
        model.nextLevel()                                                      // counter -> 3, cooldown met
        #expect(mock.maybeShowInterstitialCallCount == 1)
    }

    // MARK: Reward grant

    @Test
    func grantRewardCoins_persistsSynchronously() {
        let model = makeModel(mock: MockAdsManager())
        let before = model.progress.coins
        model.grantRewardCoins(Economy.rewardedAdPayout)
        #expect(model.progress.coins == before + Economy.rewardedAdPayout)
    }

    @Test
    func rewarded_grant_fires_once_only() {
        let mock = MockAdsManager()
        let model = makeModel(mock: mock)
        model.ads.showRewarded { model.grantRewardCoins(Economy.rewardedAdPayout) }
        #expect(mock.showRewardedCallCount == 1)
        let before = model.progress.coins
        mock.fireGrant()                                        // simulates SDK earn callback
        #expect(model.progress.coins == before + Economy.rewardedAdPayout)
        mock.fireGrant()                                        // second fire is a no-op
        #expect(model.progress.coins == before + Economy.rewardedAdPayout, "No double-grant")
    }

    // MARK: ATT first-solve trigger

    @Test
    func att_prompt_flag_flips_on_first_solve() {
        let model = makeModel(mock: MockAdsManager())
        #expect(model.progress.hasSeenAttPrompt == false)
        model.continueGame()
        guard let state = model.gameState else {
            Issue.record("gameState should be set")
            return
        }
        for c in state.puzzle.solution { placeSolutionChar(state, c) }
        #expect(model.progress.hasSeenAttPrompt == true, "ATT flag flips on first solve")
        #expect(model.shouldShowAttExplainer == true, "Explainer requested after first solve")
    }

    @Test
    func att_prompt_does_not_refire_on_second_solve() {
        let model = makeModel(mock: MockAdsManager())
        // Pre-seed as if a first solve already happened.
        model.progress.hasSeenAttPrompt = true
        model.shouldShowAttExplainer = false
        model.continueGame()
        guard let state = model.gameState else {
            Issue.record("gameState should be set")
            return
        }
        for c in state.puzzle.solution { placeSolutionChar(state, c) }
        #expect(model.shouldShowAttExplainer == false, "Explainer never re-requested")
    }

    // MARK: Progress backward-compat

    @Test
    func old_progress_blob_decodes_new_fields_to_defaults() throws {
        let json = """
        {"currentLevelIndex":0,"coins":100,"solvedIds":[],"streakDays":0,"lifetimeCheckIns":0}
        """.data(using: .utf8)!
        let progress = try JSONDecoder().decode(Progress.self, from: json)
        #expect(progress.levelsCompletedSinceInterstitial == 0)
        #expect(progress.lastInterstitialAt == nil)
        #expect(progress.hasSeenAttPrompt == false)
    }

    @Test
    func progress_round_trips_new_fields() throws {
        var progress = Progress()
        progress.levelsCompletedSinceInterstitial = 7
        progress.lastInterstitialAt = Date(timeIntervalSince1970: 1_700_000_000)
        progress.hasSeenAttPrompt = true
        let data = try JSONEncoder().encode(progress)
        let decoded = try JSONDecoder().decode(Progress.self, from: data)
        #expect(decoded.levelsCompletedSinceInterstitial == 7)
        #expect(decoded.hasSeenAttPrompt == true)
    }
}
