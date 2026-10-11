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
        // docs/releases/1.0/m2-bugs.md), so only its presence is checked here.
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

    /// M8 T57: blood pressure takes two readings, shows "120/80" and draws
    /// two lines; a reading saved before 1.1 (systolic only) still shows.
    func testBloodPressureDualValues() {
        launch(["-uitest-reset", "-uitest-seed-measurements"])
        openJourney(journeyName)

        startNewLog("测量")
        selectChip("血压")
        let systolic = app.textFields["editor.systolic"]
        waitFor(systolic)
        systolic.tap()
        systolic.typeText("120")
        let diastolic = app.textFields["editor.diastolic"]
        diastolic.tap()
        diastolic.typeText("80")
        screenshot("T57-editor")
        app.buttons["保存"].tap()
        waitFor(element(containing: "最近 血压 120/80mmHg"))

        app.buttons["measurement.group"].tap()
        waitFor(app.buttons["全部 25"])
        selectChip("血压 4")
        let rows = app.buttons.matching(identifier: "measurement.row")
        waitForCount(rows, 4)
        XCTAssertTrue(element(containing: "120/80mmHg").exists)
        XCTAssertTrue(element(containing: "118/76mmHg").exists)
        XCTAssertTrue(element(containing: "111mmHg").exists, "Legacy single-value reading missing")
        screenshot("T57-rows")

        // Editing brings both readings back.
        rows.firstMatch.tap()
        waitFor(app.navigationBars["编辑记录"])
        XCTAssertEqual(app.textFields["editor.systolic"].value as? String, "120")
        XCTAssertEqual(app.textFields["editor.diastolic"].value as? String, "80")
        app.buttons["取消"].tap()

        app.buttons["查看图表"].tap()
        waitFor(app.navigationBars["趋势 · Trends"])
        waitFor(element(containing: "4 次记录 · 收缩压 111–120 · 舒张压 72–80"))
        XCTAssertTrue(app.staticTexts["120/80"].exists)
        waitFor(element(containing: "舒张压"))
        screenshot("T57-chart")
        app.buttons["完成"].tap()

        // Persisted.
        relaunch()
        openJourney(journeyName)
        waitFor(element(containing: "最近 血压 120/80mmHg"))
    }
}
