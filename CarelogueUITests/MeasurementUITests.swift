import XCTest

/// M2 T12 (filter chips, tap-to-edit) and T13 (chart).
final class MeasurementUITests: CarelogueUITestCase {
    private let journeyName = "UITest 孕期"

    func testFilterChipsAndTapToEdit() {
        launch(["-uitest-reset", "-uitest-seed-measurements"])
        openJourney(journeyName)

        // List rows load lazily, so large sets are checked via chip counts;
        // row counts are only asserted when every row fits on screen.
        app.buttons["measurement.group"].tap()
        let rows = app.buttons.matching(identifier: "measurement.row")
        waitFor(app.buttons["全部 24"])
        XCTAssertTrue(app.buttons["体重 20"].exists)
        XCTAssertTrue(app.buttons["体温 1"].exists)

        selectChip("血压 3")
        waitForCount(rows, 3)
        screenshot("T12-filter-bp")

        // Row -> editor directly -> delete: 2 taps from the expanded list.
        rows.firstMatch.tap()
        waitFor(app.navigationBars["编辑记录"])
        app.buttons["删除记录"].tap()
        confirmDelete()
        waitForCount(rows, 2)
        waitFor(app.buttons["血压 2"])
        XCTAssertTrue(app.buttons["全部 23"].exists)

        // 体温 1 sits behind the 图表 button at the end of the chip row (see
        // docs/m2-bugs.md), so only its presence is checked here.
        XCTAssertTrue(app.buttons["体温 1"].exists)
    }

    func testChartSheet() {
        launch(["-uitest-reset", "-uitest-seed-measurements"])
        openJourney(journeyName)

        app.buttons["measurement.group"].tap()
        app.buttons["查看图表"].tap()
        waitFor(app.navigationBars["趋势 · Trends"])
        waitFor(element(containing: "20 次记录"))
        screenshot("T13-chart-weight")

        // Single-point type renders without crashing and shows the hint.
        app.buttons["体温"].tap()
        waitFor(element(containing: "只有 1 条记录"))

        app.buttons["完成"].tap()
        XCTAssertTrue(app.navigationBars["趋势 · Trends"].waitForNonExistence(timeout: 5))
    }
}
