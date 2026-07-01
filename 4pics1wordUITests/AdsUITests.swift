import XCTest

/// Ads UI tests. Banner presence is asserted via the `adBanner` accessibility identifier set on
/// the banner host view. The container is composed whenever ads are enabled (independent of
/// network fill), and absent entirely under `-uitest-reset` (kill-switch).
final class AdsUITests: XCTestCase {
    private static let resetFlag = "-uitest-reset"

    /// HomeView title — stable anchor across persisted-state variations (unlike the Play/Continue
    /// button whose label depends on `currentLevelIndex`).
    private func waitForHome(_ app: XCUIApplication) -> Bool {
        app.staticTexts["4 Pics 1 Word"].waitForExistence(timeout: 25)
    }

    @MainActor
    func test_banner_absent_under_uitest_reset() {
        let app = XCUIApplication()
        app.launchArguments += [Self.resetFlag]
        app.launch()
        XCTAssertTrue(waitForHome(app), "Home should appear after splash")
        XCTAssertFalse(app.otherElements["adBanner"].exists,
                       "Banner must not render under -uitest-reset (kill-switch)")
    }

    @MainActor
    func test_banner_present_when_ads_enabled() {
        let app = XCUIApplication()
        // No reset flag -> ads enabled -> banner container composed on HomeView.
        app.launch()
        XCTAssertTrue(waitForHome(app), "Home should appear after splash")
        XCTAssertTrue(app.otherElements["adBanner"].waitForExistence(timeout: 15),
                       "Banner container should be present when ads are enabled")
    }
}
