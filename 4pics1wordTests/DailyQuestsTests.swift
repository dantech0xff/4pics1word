import Testing
import Foundation
@testable import _pics1word

private func makePuzzle(_ solution: String, id: Int = 1) -> Puzzle {
    Puzzle(id: id, solution: solution, copyrights: [], time: 1, rating: 1.0, difficulty: nil)
}

private func placeChar(_ state: PuzzleState, _ c: Character) {
    guard let tile = state.bankTiles.first(where: { $0.character == c }) else {
        Issue.record("No bank tile available for character \(c)")
        return
    }
    state.placeTile(tile.id)
}

/// Fill every non-locked slot with its solution character — safe after hints
/// (a locked tile's character is no longer in the bank).
private func solveRest(_ state: PuzzleState) {
    let chars = state.puzzle.solutionCharacters
    for idx in 0..<state.slotCount where !(state.slotTile[idx]?.locked == true) {
        placeChar(state, chars[idx])
    }
}

// MARK: - Roll determinism & per-user variety

struct DailyQuestRollTests {
    @Test
    func sameSeedAndDayProducesIdenticalBoard() {
        let a = DailyQuests.roll(seed: 42, day: "2026-09-25")
        let b = DailyQuests.roll(seed: 42, day: "2026-09-25")
        #expect(a.quests == b.quests)
    }

    @Test
    func differentSeedsProduceDifferentBoards() {
        // Not every pair of seeds must differ (5·4·2 = 40 possible boards), but 40
        // seeds must yield >1 distinct board — identical boards for every user would
        // mean the seed is ignored.
        let day = "2026-09-25"
        let boards = (1...40).map { DailyQuests.roll(seed: UInt64($0), day: day).quests }
        #expect(Set(boards).count > 1)
    }

    @Test
    func boardIsOrderedEasyMediumHard() {
        let board = DailyQuests.roll(seed: 7, day: "2026-09-25")
        #expect(board.quests.count == 3)
        #expect(board.quests.map(\.difficulty) == [.easy, .medium, .hard])
        #expect(board.quests.map(\.id) == [0, 1, 2])
        // Harder tiers always pay more.
        #expect(board.quests[0].reward < board.quests[2].reward)
    }

    @Test
    func boardNeverRepeatsAKind() {
        // Across many seeds/days the dedup invariant must always hold.
        for seed in 1...50 {
            let quests = DailyQuests.roll(seed: UInt64(seed), day: "2026-09-25").quests
            #expect(Set(quests.map(\.kind)).count == quests.count)
        }
    }

    @Test
    func differentDaysProduceDifferentBoards() {
        let seed: UInt64 = 99
        let boards = (1...15).map {
            DailyQuests.roll(seed: seed, day: "2026-09-\(String(format: "%02d", $0))").quests
        }
        #expect(Set(boards).count > 1)
    }
}

// MARK: - Record / claim semantics (pure state, no AppModel)

struct DailyQuestRecordTests {
    private func board(_ kind: QuestKind, target: Int = 3, reward: Int = 20) -> DailyQuestsState {
        DailyQuestsState(day: "2026-09-25", quests: [
            DailyQuest(id: 0, kind: kind, difficulty: .easy, target: target, reward: reward),
        ])
    }

    @Test
    func recordCapsProgressAtTarget() {
        var b = board(.solvePuzzles, target: 3)
        #expect(DailyQuests.record(.solvePuzzles, amount: 5, in: &b))
        #expect(b.quests[0].progress == 3)
        #expect(b.quests[0].isComplete)
    }

    @Test
    func recordSkipsCompletedQuests() {
        var b = board(.solvePuzzles, target: 1)
        #expect(DailyQuests.record(.solvePuzzles, in: &b))
        #expect(!DailyQuests.record(.solvePuzzles, in: &b))
        #expect(b.quests[0].progress == 1)
    }

    @Test
    func recordIgnoresNonMatchingKinds() {
        var b = board(.solvePuzzles)
        #expect(!DailyQuests.record(.claimCheckin, in: &b))
    }
}

// MARK: - AppModel integration

@MainActor @Suite(.serialized)
struct AppModelDailyQuestsTests {
    private func makeIsolatedModel() -> (AppModel, String) {
        let suite = "quests-test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let store = ProgressStore(defaults: defaults)
        let settings = Settings.load(defaults: defaults)
        let model = AppModel(store: store, settings: settings, settingsDefaults: defaults)
        return (model, suite)
    }

    private func cleanup(_ suite: String) {
        UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
    }

    @Test
    func ensureRollsBoardAndGeneratesSeedOnce() {
        let (model, suite) = makeIsolatedModel()
        defer { cleanup(suite) }

        model.ensureTodayQuests()

        #expect(model.todayQuests.count == 3)
        #expect(model.settings.questSeed != 0)
        let seed = model.settings.questSeed
        model.ensureTodayQuests()
        #expect(model.settings.questSeed == seed, "seed persists across re-rolls")
    }

    @Test
    func staleBoardIsReplacedOnDayRollover() {
        let (model, suite) = makeIsolatedModel()
        defer { cleanup(suite) }

        model.ensureTodayQuests()
        // Simulate a leftover board from yesterday.
        model.progress.dailyQuests = DailyQuestsState(day: "2000-01-01", quests: [
            DailyQuest(id: 0, kind: .solvePuzzles, difficulty: .easy, target: 1, reward: 1,
                       progress: 1, claimed: true),
        ])
        model.ensureTodayQuests()

        #expect(model.progress.dailyQuests?.day == DailyQuests.dayKey())
        #expect(model.todayQuests.count == 3)
        #expect(model.todayQuests.allSatisfy { $0.progress == 0 && !$0.claimed })
    }

    @Test
    func claimGrantsCoinsOnce() {
        let (model, suite) = makeIsolatedModel()
        defer { cleanup(suite) }

        model.ensureTodayQuests()
        model.progress.dailyQuests = DailyQuestsState(day: DailyQuests.dayKey(), quests: [
            DailyQuest(id: 0, kind: .solvePuzzles, difficulty: .easy, target: 1, reward: 25,
                       progress: 1),
        ])
        let before = model.progress.coins

        #expect(model.claimQuest(id: 0) == 25)
        #expect(model.progress.coins == before + 25)
        #expect(model.claimableQuestCount == 0)
        // Second claim is a no-op.
        #expect(model.claimQuest(id: 0) == nil)
        #expect(model.progress.coins == before + 25)
    }

    @Test
    func incompleteQuestCannotBeClaimed() {
        let (model, suite) = makeIsolatedModel()
        defer { cleanup(suite) }

        model.progress.dailyQuests = DailyQuestsState(day: DailyQuests.dayKey(), quests: [
            DailyQuest(id: 0, kind: .solvePuzzles, difficulty: .easy, target: 3, reward: 25),
        ])

        #expect(model.claimQuest(id: 0) == nil)
    }

    @Test
    func questClaimDoesNotFeedEarnCoinsQuest() {
        let (model, suite) = makeIsolatedModel()
        defer { cleanup(suite) }

        model.progress.dailyQuests = DailyQuestsState(day: DailyQuests.dayKey(), quests: [
            DailyQuest(id: 0, kind: .solvePuzzles, difficulty: .easy, target: 1, reward: 300,
                       progress: 1),
            DailyQuest(id: 1, kind: .earnCoins, difficulty: .hard, target: 300, reward: 60),
        ])

        model.claimQuest(id: 0)

        #expect(model.todayQuests[1].progress == 0,
                "quest payouts must not feed earn-coins quests")
    }

    @Test
    func checkInFeedsClaimCheckinAndEarnCoinsQuests() {
        let (model, suite) = makeIsolatedModel()
        defer { cleanup(suite) }

        model.progress.dailyQuests = DailyQuestsState(day: DailyQuests.dayKey(), quests: [
            DailyQuest(id: 0, kind: .claimCheckin, difficulty: .easy, target: 1, reward: 15),
            DailyQuest(id: 1, kind: .earnCoins, difficulty: .hard, target: 300, reward: 60),
        ])

        let reward = model.checkIn()

        #expect(reward == 20)
        #expect(model.todayQuests[0].isComplete)
        #expect(model.todayQuests[1].progress == 20)
    }

    @Test
    func solveFeedsSolveAndEarnCoinsQuests() {
        let (model, suite) = makeIsolatedModel()
        defer { cleanup(suite) }

        model.progress.dailyQuests = DailyQuestsState(day: DailyQuests.dayKey(), quests: [
            DailyQuest(id: 0, kind: .solvePuzzles, difficulty: .easy, target: 3, reward: 20),
            DailyQuest(id: 1, kind: .solveNoHints, difficulty: .hard, target: 3, reward: 80),
            DailyQuest(id: 2, kind: .earnCoins, difficulty: .medium, target: 300, reward: 35),
        ])
        model.continueGame()
        guard let state = model.gameState else {
            Issue.record("gameState should be set after continueGame()")
            return
        }
        for c in state.puzzle.solution { placeChar(state, c) }

        #expect(model.todayQuests[0].progress == 1)
        #expect(model.todayQuests[1].progress == 1, "no-hint solve counts toward solveNoHints")
        #expect(model.todayQuests[2].progress == model.lastReward)
    }

    @Test
    func solveWithHintDoesNotFeedSolveNoHints() {
        let (model, suite) = makeIsolatedModel()
        defer { cleanup(suite) }

        model.progress.dailyQuests = DailyQuestsState(day: DailyQuests.dayKey(), quests: [
            DailyQuest(id: 0, kind: .solveNoHints, difficulty: .hard, target: 1, reward: 80),
            DailyQuest(id: 1, kind: .useRevealHints, difficulty: .easy, target: 1, reward: 15),
        ])
        model.progress.coins = 1000
        model.continueGame()
        guard let state = model.gameState else {
            Issue.record("gameState should be set after continueGame()")
            return
        }
        state.revealHint()
        #expect(model.todayQuests[1].progress == 1, "hint use feeds its own quest immediately")
        #expect(state.usedAnyHint)
        solveRest(state)

        #expect(model.todayQuests[0].progress == 0, "hinted solve must not count as no-hint")
    }
}
