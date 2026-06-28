import XCTest

/// Daily check-in UI tests. `-uitest-reset` clears persisted progress/settings so the first
/// launch of each test is a known fresh state. The real check-in flow then runs end-to-end
/// against the real persistence layer — no fakes injected.
final class CheckInUITests: XCTestCase {

    private static let checkInView = "CheckInView"
    private static let resetFlag = "-uitest-reset"

    func testCheckInSheetAutoAppearsOnFirstLaunch() {
        let app = XCUIApplication()
        app.launchArguments += [Self.resetFlag]
        app.launch()

        // Splash (~1.5s) + 0.4s auto-fire delay, plus generous slack for simulator
        // cold-start / debugger-attach overhead on the first launch of a run.
        let sheet = app.otherElements[Self.checkInView]
        XCTAssertTrue(sheet.waitForExistence(timeout: 25), "Check-in sheet did not auto-present on first launch")
    }

    func testClaimShowsThenComeBackTomorrow() {
        let app = XCUIApplication()
        app.launchArguments += [Self.resetFlag]
        app.launch()

        let claim = app.buttons["Claim 20 coins"]
        XCTAssertTrue(claim.waitForExistence(timeout: 25), "Day-1 Claim button (20 coins) not found")
        claim.tap()

        let comeback = app.staticTexts["Come back tomorrow"]
        XCTAssertTrue(comeback.waitForExistence(timeout: 5), "Claim did not transition to come-back state")
        XCTAssertFalse(claim.exists, "Claim button should disappear after claiming")
    }

    func testNoAutoSheetOnRelaunchAfterClaim() {
        let app = XCUIApplication()
        app.launchArguments += [Self.resetFlag]
        app.launch()

        // Claim today's reward so progress.lastCheckInDate is persisted.
        let claim = app.buttons["Claim 20 coins"]
        XCTAssertTrue(claim.waitForExistence(timeout: 25))
        claim.tap()

        // Relaunch WITHOUT the reset flag → persisted claim survives → canCheckInToday is false.
        app.launchArguments.removeAll()
        app.launch()

        let play = app.buttons["Play"]
        XCTAssertTrue(play.waitForExistence(timeout: 25), "Home did not appear on relaunch")

        // Auto-fire (if any) lands by ~1.9s after launch; give it 4s then assert it never appeared.
        let sheet = app.otherElements[Self.checkInView]
        XCTAssertFalse(sheet.waitForExistence(timeout: 4), "Sheet should not auto-present after claiming today")
    }

    func testToolbarButtonReopensSheetAfterDismiss() {
        let app = XCUIApplication()
        app.launchArguments += [Self.resetFlag]
        app.launch()

        let sheet = app.otherElements[Self.checkInView]
        XCTAssertTrue(sheet.waitForExistence(timeout: 25))

        // Phase 01 gate: Close is disabled pre-claim. Must claim first to enable dismissal.
        let claim = app.buttons["Claim 20 coins"]
        XCTAssertTrue(claim.waitForExistence(timeout: 5), "Day-1 Claim button not found")
        claim.tap()

        // Post-claim Close is enabled → explicit dismiss (deterministic vs swipe gesture).
        let close = app.buttons["Close"]
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        XCTAssertTrue(close.isEnabled, "Close must be enabled after claim (gate should have lifted)")
        close.tap()

        let toolbar = app.buttons["Daily check-in"]
        XCTAssertTrue(toolbar.waitForExistence(timeout: 5), "Check-in toolbar button not found after dismiss")
        toolbar.tap()
        XCTAssertTrue(sheet.waitForExistence(timeout: 5), "Toolbar button did not reopen the sheet")
    }

    func testCloseIsDisabledBeforeClaim() {
        let app = XCUIApplication()
        app.launchArguments += [Self.resetFlag]
        app.launch()

        let sheet = app.otherElements[Self.checkInView]
        XCTAssertTrue(sheet.waitForExistence(timeout: 25))

        // Gate contract: Close exists, is in the a11y tree, but is disabled while reward claimable.
        let close = app.buttons["Close"]
        XCTAssertTrue(close.exists, "Close button must remain in the accessibility tree when disabled")
        XCTAssertFalse(close.isEnabled, "Close must be disabled while reward is claimable")

        // Tap on a disabled button is a no-op for XCTest; sheet must stay presented.
        XCTAssertTrue(sheet.exists, "Sheet should not dismiss pre-claim")
    }
}
