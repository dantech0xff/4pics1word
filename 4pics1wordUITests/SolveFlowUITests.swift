import XCTest

/// End-to-end UI test: Home → Play → solve level 1 (MOUSE) → Win sheet.
/// Level 1's pool is deterministic (seeded by puzzle id), but we drive it by tapping the
/// needed letters regardless of their grid position — the bank re-renders as tiles are placed.
final class SolveFlowUITests: XCTestCase {
    func testSolveLevel1() throws {
        let app = XCUIApplication()
        app.launch()

        // Splash auto-dismisses (~1.5s); wait for the Home Play button.
        let play = app.buttons["Play"]
        XCTAssertTrue(play.waitForExistence(timeout: 10), "Home Play button never appeared")
        play.tap()

        // Solve MOUSE by tapping each needed letter (auto-fills first empty slot).
        // The bank pool can contain duplicate decoy letters, so match the first
        // available tile rather than assuming a unique label per character.
        for letter in ["M", "O", "U", "S", "E"] {
            let tile = app.buttons.matching(identifier: letter).firstMatch
            XCTAssertTrue(tile.waitForExistence(timeout: 5), "Bank tile \(letter) not found")
            tile.tap()
        }

        // The 5th placement fills the board → win → WinView sheet with "Next Level".
        let next = app.buttons["Next Level"]
        XCTAssertTrue(next.waitForExistence(timeout: 5), "Win sheet did not appear after solving")
    }
}
