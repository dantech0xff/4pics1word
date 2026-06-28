import XCTest

/// UI smoke for the grid-area image zoom: tapping a picture enlarges it over the
/// grid only (hint bar stays visible), and tapping the enlarged image dismisses it.
/// Works on any level since the 2×2 "Picture N of 4" cells are always present.
final class ImageZoomUITests: XCTestCase {
    func testTapPictureZoomsThenDismisses() throws {
        let app = XCUIApplication()
        app.launch()

        // Home shows "Play" (fresh install) or "Continue" (saved progress).
        let entry = app.buttons.matching(NSPredicate(format: "label IN {'Play','Continue'}")).firstMatch
        XCTAssertTrue(entry.waitForExistence(timeout: 10), "Home entry button never appeared")
        entry.tap()

        let cell = app.buttons["Picture 1 of 4"]
        XCTAssertTrue(cell.waitForExistence(timeout: 5), "Picture cell not found")

        // Zoom in: the source cell is hidden while zoomed.
        cell.tap()
        XCTAssertTrue(cell.waitForNonExistence(timeout: 3), "Cell should hide after zoom-in")

        // The enlarged image covers the whole grid, so the other cells are not tappable.
        XCTAssertFalse(app.buttons["Picture 2 of 4"].isHittable, "Other cells should be covered by the enlarged image")

        // The hint bar must remain visible while the image is enlarged (not covered).
        let reveal = app.buttons.containing(NSPredicate(format: "label CONTAINS 'Reveal'")).firstMatch
        XCTAssertTrue(reveal.exists, "Hint bar should stay visible while zoomed")

        // Dismiss by tapping the enlarged image (overlay exposes a "…enlarged…" label).
        let bigPic = app.buttons.containing(NSPredicate(format: "label CONTAINS 'enlarged'")).firstMatch
        XCTAssertTrue(bigPic.waitForExistence(timeout: 3), "Enlarged image not shown")
        bigPic.tap()

        // Zoom out: the cell animates back into the grid.
        XCTAssertTrue(cell.waitForExistence(timeout: 3), "Cell did not return after dismiss")
    }
}
