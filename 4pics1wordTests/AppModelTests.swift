import Testing
import Foundation
@testable import _pics1word

// MARK: - Local helpers (file-private)

private func placeChar(_ state: PuzzleState, _ c: Character) {
    guard let tile = state.bankTiles.first(where: { $0.character == c }) else {
        Issue.record("No bank tile available for character \(c)")
        return
    }
    state.placeTile(tile.id)
}

// MARK: - Seamless level loop

@MainActor @Suite(.serialized)
struct AppModelProgressLoopTests {
    @Test
    func solvingLastLevelWrapsToFirst() throws {
        let model = AppModel()
        let lastIndex = model.totalLevels - 1
        #expect(lastIndex >= 1, "Need at least 2 levels to validate wrap-around")

        model.progress.currentLevelIndex = lastIndex
        model.continueGame()

        guard let state = model.gameState else {
            Issue.record("gameState should be set after continueGame()")
            return
        }

        // Drive the real win path — onSolved fires handleSolved synchronously.
        for c in state.puzzle.solution { placeChar(state, c) }

        // Phase 01: solve sets `.celebrating` (deferred), not `.won`. Engine truth is `.won`.
        #expect(state.phase == .won)
        #expect(model.phase == .celebrating)
        // Reward/persist/index-advance happened synchronously at solve moment (no progress loss).
        #expect(model.progress.currentLevelIndex == 0, "Index must wrap to 0 after the final level")
        #expect(model.hasNextLevel, "Loop must always offer a next level")
        #expect(model.currentLevelNumber == 1)
        // Wave-end flips `.celebrating` → `.won` → presents WinView sheet.
        model.completeSolve()
        #expect(model.phase == .won)
    }

    @Test
    func solvingMidLevelAdvancesByOne() throws {
        let model = AppModel()
        #expect(model.totalLevels >= 3, "Need at least 3 levels")
        model.progress.currentLevelIndex = 1
        model.continueGame()

        guard let state = model.gameState else {
            Issue.record("gameState should be set after continueGame()")
            return
        }
        for c in state.puzzle.solution { placeChar(state, c) }

        // Phase 01: reward/advance happen synchronously; phase defers to `.celebrating`.
        #expect(model.progress.currentLevelIndex == 2, "Non-final solve advances by exactly one")
        #expect(model.currentLevelNumber == 3)
        #expect(model.phase == .celebrating)
        model.completeSolve()
        #expect(model.phase == .won)
    }
}

// MARK: - Appearance preference

struct SettingsAppearanceTests {
    @Test
    func appearanceDefaultsToLight() {
        #expect(Settings().appearance == .light)
    }

    @Test
    func appearanceRoundTripsThroughCodable() throws {
        var settings = Settings()
        settings.appearance = .dark
        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(Settings.self, from: data)
        #expect(decoded.appearance == .dark)
    }

    @Test
    func appearancePersistsAcrossLoadSaveCycle() {
        let suiteName = "AppModelAppearanceTest.\(UUID().uuidString)"
        let suite = UserDefaults(suiteName: suiteName)!
        defer { suite.removePersistentDomain(forName: suiteName) }

        var settings = Settings.load(defaults: suite)
        settings.appearance = .dark
        settings.save(defaults: suite)

        let reloaded = Settings.load(defaults: suite)
        #expect(reloaded.appearance == .dark)
    }
}
