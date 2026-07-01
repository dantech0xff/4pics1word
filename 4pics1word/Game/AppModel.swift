import Foundation
import Observation

enum AppPhase: Equatable {
    case home
    case playing
    case celebrating
    case won
}

/// App-wide orchestrator: owns progress, settings, the active puzzle, and the screen phase.
@Observable
final class AppModel {
    let service: LevelService
    let store: ProgressStore
    private let settingsDefaults: UserDefaults
    var progress: Progress
    var settings: Settings
    var phase: AppPhase = .home
    var gameState: PuzzleState?
    var lastReward: Int = 0
    var lastCheckInReward: Int = 0
    /// Set on the first ever solve so AppRootView can present the ATT explainer sheet.
    /// Gated to present only when `phase == .home` (see AppRootView) to avoid clashing with WinView.
    var shouldShowAttExplainer = false
    let ads: AdsManaging
    /// Safety-net Task that flips `.celebrating` → `.won` if GameView's wave-driver
    /// never calls `completeSolve()` (e.g. view dismissed mid-wave). Normal path is
    /// the explicit `completeSolve()` from GameView at wave-end.
    private var celebrationTask: Task<Void, Never>?

    init(service: LevelService = .load(),
         store: ProgressStore = .init(),
         settings: Settings? = nil,
         settingsDefaults: UserDefaults = .standard,
         ads: AdsManaging = AdsManager()) {
        self.service = service
        self.store = store
        self.settingsDefaults = settingsDefaults
        self.settings = settings ?? Settings.load(defaults: settingsDefaults)
        self.progress = store.load()
        self.ads = ads
        Feedback.enabled = self.settings.hapticsEnabled
    }

    // MARK: Derived

    var totalLevels: Int { service.count }
    var currentLevelNumber: Int { progress.currentLevelIndex + 1 }
    var hasNextLevel: Bool { progress.currentLevelIndex < totalLevels }
    var canCheckInToday: Bool { CheckIn.canClaim(progress) }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        return f
    }()

    private var todayKey: String { Self.dayFormatter.string(from: Date()) }
    var hasSeenCheckinSheetToday: Bool { settings.lastCheckinSheetDay == todayKey }
    func markCheckinSheetSeen() {
        settings.lastCheckinSheetDay = todayKey
        settings.save(defaults: settingsDefaults)
    }

    // MARK: Flow

    func continueGame() {
        guard hasNextLevel else { return }
        startLevel(at: progress.currentLevelIndex)
    }

    func startLevel(at index: Int) {
        guard let puzzle = service[index] else { return }
        let state = PuzzleState(puzzle: puzzle, coins: progress.coins) { [weak self] solved in
            self?.handleSolved(solved)
        }
        gameState = state
        phase = .playing
    }

    /// Called from PuzzleState.onSolved (spec §4.3 — AppModel applies reward + persists + advances).
    /// Reward/persist/index-advance happen synchronously here (never deferred ⇒ no progress loss).
    /// Phase flips to `.celebrating` (NOT `.won`); GameView's wave-driver calls `completeSolve()`
    /// at animation end to present the WinView sheet. Safety-net Task guards against missed calls.
    private func handleSolved(_ state: PuzzleState) {
        let tier = service.strategy.tier(for: progress.currentLevelIndex)
        let reward = Economy.reward(forTier: tier)
        progress.coins = state.coins + reward
        progress.solvedIds.insert(state.puzzle.id)
        // Loop seamlessly: after the final level, wrap back to the first.
        // The total is never surfaced to the user, so completion is invisible.
        progress.currentLevelIndex = (progress.currentLevelIndex + 1) % totalLevels
        lastReward = reward
        store.save(progress)
        // ATT prompt timing (locked decision): after the FIRST ever solve. Flip the flag
        // synchronously so it can't re-fire; AppRootView presents the explainer sheet when
        // the player is back at home (gated by phase to avoid clashing with WinView).
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

    /// Once-per-calendar-day coin claim. Returns reward amount, or nil if already claimed today
    /// or clock-rewind is suspected. Mirrors the `handleSolved` reward path (Decision Point B:
    /// check-in is additive to solve-rewards). Advances the `lastKnownNow` high-water mark only
    /// on a legitimate claim — never on a rewind-suspected attempt (prevents ratchet-down).
    func checkIn() -> Int? {
        guard CheckIn.canClaim(progress) else { return nil }
        let day = CheckIn.nextStreakDay(progress)
        let reward = CheckIn.reward(forStreakDay: day)
        progress.streakDays = day
        progress.coins += reward
        progress.lastCheckInDate = Date()
        progress.lifetimeCheckIns += 1
        progress.lastKnownNow = Date()
        lastCheckInReward = reward
        store.save(progress)
        return reward
    }

    /// Flip `.celebrating` → `.won` (presents WinView sheet). Idempotent: no-op when already
    /// `.won`/`.home`/`.playing`. Cancels the safety-net Task — explicit completion wins.
    func completeSolve() {
        celebrationTask?.cancel()
        celebrationTask = nil
        guard phase == .celebrating else { return }
        phase = .won
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

    /// Interstitial eligibility: every 3rd completed level AND ≥60s since the last show.
    /// `AppModel` owns the math (unit-testable via `MockAdsManager`); `ads.maybeShowInterstitial`
    /// only checks ad-readiness.
    private var shouldShowInterstitial: Bool {
        let cooldown: TimeInterval = 60
        let last = progress.lastInterstitialAt ?? .distantPast
        return progress.levelsCompletedSinceInterstitial >= 3
            && Date().timeIntervalSince(last) >= cooldown
    }

    /// Reward-video payout path. Called from `AdsManager.showRewarded`'s earn-reward closure.
    /// Single mutation gate: coin changes flow through AppModel, persist synchronously.
    func grantRewardCoins(_ amount: Int) {
        progress.coins += amount
        store.save(progress)
    }

    func exitToHome() {
        celebrationTask?.cancel(); celebrationTask = nil
        // Commit coins spent on hints mid-level (prevents refund-on-exit exploit)
        if let state = gameState {
            progress.coins = state.coins
            store.save(progress)
        }
        gameState = nil
        phase = .home
    }

    func resetProgress() {
        celebrationTask?.cancel(); celebrationTask = nil
        store.reset()
        progress = Progress()
        gameState = nil
        phase = .home
    }

    func updateHaptics(_ enabled: Bool) {
        settings.hapticsEnabled = enabled
        Feedback.enabled = enabled
        settings.save(defaults: settingsDefaults)
    }

    func updateAppearance(_ preference: AppearancePreference) {
        settings.appearance = preference
        settings.save(defaults: settingsDefaults)
    }

    /// Unique photo attributions across all bundled levels (legal: credit all included art).
    var allCredits: [String] {
        let seen = NSMutableOrderedSet()
        for level in service.levels {
            for credit in level.copyrights where !seen.contains(credit) {
                seen.add(credit)
            }
        }
        return seen.array.compactMap { $0 as? String }
    }
}
