import Foundation
import Observation

enum AppPhase: Equatable {
    case home
    case playing
    case won
}

/// App-wide orchestrator: owns progress, settings, the active puzzle, and the screen phase.
@Observable
final class AppModel {
    let service: LevelService
    let store: ProgressStore
    var progress: Progress
    var settings: Settings
    var phase: AppPhase = .home
    var gameState: PuzzleState?
    var lastReward: Int = 0

    init(service: LevelService = .load(),
         store: ProgressStore = .init(),
         settings: Settings = .load()) {
        self.service = service
        self.store = store
        self.settings = settings
        self.progress = store.load()
        Feedback.enabled = settings.hapticsEnabled
    }

    // MARK: Derived

    var totalLevels: Int { service.count }
    var currentLevelNumber: Int { min(progress.currentLevelIndex + 1, totalLevels) }
    var hasNextLevel: Bool { progress.currentLevelIndex < totalLevels }
    var isComplete: Bool { progress.currentLevelIndex >= totalLevels }

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
    private func handleSolved(_ state: PuzzleState) {
        let tier = service.strategy.tier(for: progress.currentLevelIndex)
        let reward = Economy.reward(forTier: tier)
        progress.coins = state.coins + reward
        progress.solvedIds.insert(state.puzzle.id)
        if progress.currentLevelIndex < totalLevels - 1 {
            progress.currentLevelIndex += 1
        } else {
            progress.currentLevelIndex = totalLevels  // mark all complete
        }
        lastReward = reward
        store.save(progress)
        phase = .won
    }

    func nextLevel() {
        guard hasNextLevel else { phase = .home; return }
        startLevel(at: progress.currentLevelIndex)
    }

    func exitToHome() {
        // Commit coins spent on hints mid-level (prevents refund-on-exit exploit)
        if let state = gameState {
            progress.coins = state.coins
            store.save(progress)
        }
        gameState = nil
        phase = .home
    }

    func resetProgress() {
        store.reset()
        progress = Progress()
        gameState = nil
        phase = .home
    }

    func updateHaptics(_ enabled: Bool) {
        settings.hapticsEnabled = enabled
        Feedback.enabled = enabled
        settings.save()
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
