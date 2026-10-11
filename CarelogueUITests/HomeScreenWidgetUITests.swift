import XCTest

/// M8 T58: the real widget on the simulator's home screen — the extension
/// loads, reads the App Group snapshot and draws it. Driven through
/// SpringBoard's own widget gallery, so it is the most fragile test here.
final class HomeScreenWidgetUITests: CarelogueUITestCase {
    func testAddWidgetToHomeScreen() throws {
        launch(["-uitest-reset", "-uitest-seed-demo"])
        waitFor(app.navigationBars["Journeys"])
        sleep(2) // let the snapshot be written
        XCUIDevice.shared.press(.home)
        sleep(1)

        // Long-press the wallpaper -> edit mode.
        springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75)).press(forDuration: 1.6)
        let addWidget = springboard.buttons["Add Widget"]
        XCTAssertTrue(addWidget.waitForExistence(timeout: 5))
        addWidget.tap()
        sleep(2)
        let search = springboard.searchFields.firstMatch
        if search.waitForExistence(timeout: 5) {
            search.tap()
            search.typeText("Carelogue")
        }
        let cell = springboard.cells["Carelogue"]
        XCTAssertTrue(cell.waitForExistence(timeout: 5), "Carelogue is not in the widget gallery")
        cell.tap()
        sleep(2)

        // Small first; swipe once for the medium size, then add it.
        springboard.swipeLeft()
        sleep(1)
        screenshot("T58-gallery-medium")
        // The sheet's own "Add Widget" sits at the bottom; edit mode has a
        // second button with the same label behind the sheet.
        springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.947)).tap()
        sleep(2)
        let done = springboard.buttons["Done"]
        if done.waitForExistence(timeout: 3) { done.tap() }
        sleep(3)
        screenshot("T58-home-widget")

        // SpringBoard exposes the widget as one element named after the app
        // (its contents aren't in the accessibility tree; the screenshot
        // shows them): a medium widget is far wider than an app icon.
        let widgets = springboard.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "Carelogue")).allElementsBoundByIndex
        XCTAssertTrue(widgets.contains { $0.frame.width > 250 }, "No Carelogue widget on the home screen")
    }
}
