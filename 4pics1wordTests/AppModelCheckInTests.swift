import Testing
import Foundation
@testable import _pics1word

@MainActor @Suite(.serialized)
struct AppModelCheckInTests {

    private func makeIsolatedModel() -> (AppModel, String) {
        let suite = "checkin-test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let store = ProgressStore(defaults: defaults)
        let settings = Settings.load(defaults: defaults)
        let model = AppModel(store: store, settings: settings, settingsDefaults: defaults)
        return (model, suite)
    }

    private func cleanup(_ suite: String) {
        UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
    }

    // MARK: - First claim

    @Test
    func firstClaimAwards20Coins() {
        let (model, suite) = makeIsolatedModel()
        defer { cleanup(suite) }

        let reward = model.checkIn()

        #expect(reward == 20)
        #expect(model.progress.coins == Progress.startingCoins + 20)
        #expect(model.progress.streakDays == 1)
        #expect(model.progress.lifetimeCheckIns == 1)
        #expect(model.lastCheckInReward == 20)
        #expect(model.progress.lastCheckInDate != nil)
        #expect(model.progress.lastKnownNow != nil)
    }

    // MARK: - Double claim same day

    @Test
    func doubleClaimSameDayReturnsNilAndChangesNothing() {
        let (model, suite) = makeIsolatedModel()
        defer { cleanup(suite) }

        let first = model.checkIn()
        let coinsAfterFirst = model.progress.coins
        let second = model.checkIn()

        #expect(first == 20)
        #expect(second == nil)
        #expect(model.progress.coins == coinsAfterFirst)
        #expect(model.progress.streakDays == 1)
        #expect(model.progress.lifetimeCheckIns == 1)
    }

    // MARK: - Claim next day (streak continues)

    @Test
    func claimNextDayContinuesStreak() {
        let (model, suite) = makeIsolatedModel()
        defer { cleanup(suite) }

        model.progress.streakDays = 1
        model.progress.lastCheckInDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())

        let reward = model.checkIn()

        #expect(reward == 25)
        #expect(model.progress.streakDays == 2)
        #expect(model.progress.coins == Progress.startingCoins + 25)
        #expect(model.progress.lifetimeCheckIns == 1)
        #expect(model.canCheckInToday == false)
    }

    // MARK: - Claim after gap (streak resets)

    @Test
    func claimAfterGapResetsStreak() {
        let (model, suite) = makeIsolatedModel()
        defer { cleanup(suite) }

        model.progress.streakDays = 5
        model.progress.lastCheckInDate = Calendar.current.date(byAdding: .day, value: -3, to: Date())

        let reward = model.checkIn()

        #expect(reward == 20)
        #expect(model.progress.streakDays == 1)
        #expect(model.progress.coins == Progress.startingCoins + 20)
    }

    // MARK: - Day 8 wraps

    @Test
    func day8ClaimWrapsToTier1Reward() {
        let (model, suite) = makeIsolatedModel()
        defer { cleanup(suite) }

        model.progress.streakDays = 7
        model.progress.lastCheckInDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())

        let reward = model.checkIn()

        #expect(reward == 20)
        #expect(model.progress.streakDays == 8)
        #expect(model.progress.coins == Progress.startingCoins + 20)
    }

    // MARK: - Rewind blocks

    @Test
    func rewindSuspectedBlocksClaim() {
        let (model, suite) = makeIsolatedModel()
        defer { cleanup(suite) }

        model.progress.lastKnownNow = Date().addingTimeInterval(3600)
        let coinsBefore = model.progress.coins

        let reward = model.checkIn()

        #expect(reward == nil)
        #expect(model.progress.coins == coinsBefore)
        #expect(model.progress.streakDays == 0)
        #expect(model.canCheckInToday == false)
    }

    // MARK: - resetProgress clears check-in state

    @Test
    func resetProgressClearsCheckInState() {
        let (model, suite) = makeIsolatedModel()
        defer { cleanup(suite) }

        _ = model.checkIn()
        #expect(model.progress.streakDays == 1)
        #expect(model.canCheckInToday == false)

        model.resetProgress()

        #expect(model.progress.streakDays == 0)
        #expect(model.progress.lastCheckInDate == nil)
        #expect(model.progress.lifetimeCheckIns == 0)
        #expect(model.canCheckInToday == true)
    }

    // MARK: - canCheckInToday mirrors canClaim

    @Test
    func canCheckInTodayTrueBeforeAnyClaim() {
        let (model, suite) = makeIsolatedModel()
        defer { cleanup(suite) }
        #expect(model.canCheckInToday == true)
    }

    @Test
    func canCheckInTodayFalseAfterClaim() {
        let (model, suite) = makeIsolatedModel()
        defer { cleanup(suite) }
        _ = model.checkIn()
        #expect(model.canCheckInToday == false)
    }

    // MARK: - Sheet gate (Settings.lastCheckinSheetDay)

    @Test
    func hasSeenCheckinSheetTodayFalseInitially() {
        let (model, suite) = makeIsolatedModel()
        defer { cleanup(suite) }
        #expect(model.hasSeenCheckinSheetToday == false)
    }

    @Test
    func markCheckinSheetSeenSetsTodayKey() {
        let (model, suite) = makeIsolatedModel()
        defer { cleanup(suite) }

        #expect(model.hasSeenCheckinSheetToday == false)
        model.markCheckinSheetSeen()
        #expect(model.hasSeenCheckinSheetToday == true)
    }

    // MARK: - Persistence round-trips streak fields

    @Test
    func streakFieldsPersistAcrossStoreReload() {
        let suite = "checkin-persist-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { cleanup(suite) }

        let store1 = ProgressStore(defaults: defaults)
        let model = AppModel(store: store1)
        model.progress.streakDays = 4
        model.progress.lastCheckInDate = Date()
        model.progress.lifetimeCheckIns = 9
        store1.save(model.progress)

        let store2 = ProgressStore(defaults: defaults)
        let reloaded = store2.load()

        #expect(reloaded.streakDays == 4)
        #expect(reloaded.lifetimeCheckIns == 9)
        #expect(reloaded.lastCheckInDate != nil)
    }

    // MARK: - Forward-compat: old blob (no new keys) decodes to defaults

    @Test
    func oldProgressBlobDecodesCheckInFieldsToDefaults() throws {
        let suite = "checkin-compat-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { cleanup(suite) }

        let legacyJSON = """
        {"currentLevelIndex":2,"coins":250,"solvedIds":[1,2,3]}
        """.data(using: .utf8)!
        defaults.set(legacyJSON, forKey: "progress.v1")

        let store = ProgressStore(defaults: defaults)
        let loaded = store.load()

        #expect(loaded.currentLevelIndex == 2)
        #expect(loaded.coins == 250)
        #expect(loaded.solvedIds == [1, 2, 3])
        #expect(loaded.lastCheckInDate == nil)
        #expect(loaded.streakDays == 0)
        #expect(loaded.lifetimeCheckIns == 0)
        #expect(loaded.lastKnownNow == nil)
    }
}
