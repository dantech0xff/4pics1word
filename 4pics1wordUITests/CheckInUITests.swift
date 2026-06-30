import XCTest

/// Daily check-in UI tests. `-uitest-reset` clears persisted progress/settings so the first
/// launch of each test is a known fresh state. The real check-in flow then runs end-to-end
/// against the real persistence layer — no fakes injected.
final class CheckInUITests: XCTestCase {

    private static let checkInView = "CheckInView"
    private static let resetFlag = "-uitest-reset"

    /// Launches the app with persisted state cleared so the check-in sheet auto-presents
    /// at day 1 of a fresh streak. Shared by the new Phase-05 tests.
    @discardableResult
    private func launchFresh() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [Self.resetFlag]
        app.launch()
        return app
    }

    private func waitForSheet(_ app: XCUIApplication) -> XCUIElement {
        let sheet = app.otherElements[Self.checkInView]
        XCTAssertTrue(sheet.waitForExistence(timeout: 25), "Check-in sheet did not present")
        return sheet
    }

    /// Waits for `element` to leave the a11y tree. Returns true if it disappeared within `timeout`.
    @discardableResult
    private func waitForDisappearance(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        let gone = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: gone, object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    func testCheckInSheetAutoAppearsOnFirstLaunch() {
        let app = XCUIApplication()
        app.launchArguments += [Self.resetFlag]
        app.launch()

        // Splash (~1.5s) + 0.4s auto-fire delay, plus generous slack for simulator
        // cold-start / debugger-attach overhead on the first launch of a run.
        let sheet = app.otherElements[Self.checkInView]
        XCTAssertTrue(sheet.waitForExistence(timeout: 25), "Check-in sheet did not auto-present on first launch")
    }

    func testClaimShowsCountdown() {
        let app = launchFresh()
        _ = waitForSheet(app)

        let claim = app.buttons["Claim 20 coins"]
        XCTAssertTrue(claim.waitForExistence(timeout: 25), "Day-1 Claim button (20 coins) not found")
        claim.tap()

        let countdown = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "Next reward")).firstMatch
        XCTAssertTrue(countdown.waitForExistence(timeout: 5),
                      "Claim did not transition to countdown state")
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

    /// Tap the dimmed area above a `.medium` sheet (the real "tap outside to dismiss"
    /// gesture). More reliable than `swipeDown()` on sheet content, which can be
    /// absorbed by the sheet and never cross the dismiss threshold.
    private func tapOutsideSheet(in app: XCUIApplication) {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1)).tap()
    }

    func testToolbarButtonReopensSheetAfterDismiss() {
        let app = launchFresh()
        let sheet = waitForSheet(app)

        // Pre-claim the sheet is non-dismissable; claim first to lift the gate.
        let claim = app.buttons["Claim 20 coins"]
        XCTAssertTrue(claim.waitForExistence(timeout: 5), "Day-1 Claim button not found")
        claim.tap()

        // Confirm the claim took effect (gate lifts) before we try to dismiss.
        let countdown = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "Next reward")).firstMatch
        XCTAssertTrue(countdown.waitForExistence(timeout: 5),
                      "Claim did not transition to countdown state")

        // Post-claim: tap-outside is now the dismiss path — no Close button.
        tapOutsideSheet(in: app)
        XCTAssertTrue(waitForDisappearance(sheet, timeout: 5), "Sheet should dismiss via tap-outside after claiming")

        let toolbar = app.buttons["Daily check-in"]
        XCTAssertTrue(toolbar.waitForExistence(timeout: 5), "Check-in toolbar button not found after dismiss")
        toolbar.tap()
        XCTAssertTrue(sheet.waitForExistence(timeout: 5), "Toolbar button did not reopen the sheet")
    }

    /// The sheet cannot be dismissed before today's reward is claimed. There is no Close
    /// button; the gate is `.interactiveDismissDisabled(model.canCheckInToday)`.
    func testSheetNotDismissableBeforeClaim() {
        let app = launchFresh()
        let sheet = waitForSheet(app)

        // Tapping outside (which WOULD dismiss when allowed) must be blocked pre-claim.
        tapOutsideSheet(in: app)
        XCTAssertTrue(sheet.waitForExistence(timeout: 2), "Sheet must not dismiss before claiming")
        XCTAssertTrue(app.buttons["Claim 20 coins"].exists, "Claim button should still be present (pre-claim)")
    }

    // MARK: - Phase 05: progress dots + jackpot cell

    func testProgressDotsRowExists() {
        let app = launchFresh()
        _ = waitForSheet(app)

        // Query by label (not identifier): SwiftUI custom `.accessibilityElement` containers
        // expose their label reliably across element types. The dots row reads "N of 7".
        let dots = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "of 7")).firstMatch
        XCTAssertTrue(dots.waitForExistence(timeout: 10), "Progress dots row not found")
        XCTAssertTrue(dots.label.contains("0 of 7"), "Fresh progress should read '0 of 7', got: \(dots.label)")
    }

    func testJackpotDayUsesGiftIcon() {
        let app = launchFresh()
        _ = waitForSheet(app)

        // Day-7 jackpot cell is differentiated by a `gift.fill` icon (not directly assertable
        // via XCTest) + an a11y label that reads "jackpot". Match by label predicate.
        let jackpot = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "jackpot")).firstMatch
        XCTAssertTrue(jackpot.waitForExistence(timeout: 10), "Day-7 jackpot tile not found")
        let label = jackpot.label.lowercased()
        XCTAssertTrue(label.contains("jackpot"), "Day-7 label should read 'jackpot', got: \(jackpot.label)")
        XCTAssertTrue(label.contains("100"), "Day-7 should offer 100 coins, got: \(jackpot.label)")
    }

    // MARK: - Phase 04: 3-3-1 grid + countdown

    /// Day-7 jackpot tile is present as a full-width row in the 3-3-1 layout (visual width
    /// is not assertable via XCTest, so assert presence + jackpot identity only).
    func testJackpotTileFullWidthRow() {
        let app = launchFresh()
        _ = waitForSheet(app)

        let jackpot = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "jackpot")).firstMatch
        XCTAssertTrue(jackpot.waitForExistence(timeout: 10), "Day-7 jackpot tile not found")
        XCTAssertTrue(jackpot.label.contains("100"), "Day-7 should offer 100 coins, got: \(jackpot.label)")
    }

    func testCountdownIdentifierPostClaim() {
        let app = launchFresh()
        _ = waitForSheet(app)

        app.buttons["Claim 20 coins"].tap()

        // Identifier-based query; fall back to label match if SwiftUI surfaces the element
        // under a different XCTest type than `otherElement`.
        let byIdentifier = app.otherElements["CheckInCountdown"]
        if byIdentifier.waitForExistence(timeout: 5) { return }
        let byLabel = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "Next reward")).firstMatch
        XCTAssertTrue(byLabel.waitForExistence(timeout: 5),
                      "Countdown not found post-claim (tried identifier + label match)")
    }
}
