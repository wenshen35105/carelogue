import XCTest

/// CLAUDE.md Smoke checklist, end to end through the real UI.
final class SmokeUITests: CarelogueUITestCase {
    func testSmokeChecklist() {
        // 1. Launch without crashing (clean store).
        launch(["-uitest-reset"])
        waitFor(app.navigationBars["Journeys"])

        // 2. Create a Journey: + -> name -> template.
        button(containing: "新建健康旅程").tap()
        let nameField = app.textFields.firstMatch
        waitFor(nameField)
        nameField.typeText("Smoke 旅程")
        app.buttons["下一步"].tap()
        let template = app.buttons["孕期"]
        waitFor(template)
        template.tap()
        openJourney("Smoke 旅程")

        // 3. One Log of each kind.
        startNewLog("就诊")
        selectChip("面诊")
        app.buttons["保存"].tap()
        waitFor(element(containing: "就诊 · 面诊"))

        startNewLog("随手记")
        app.textViews.firstMatch.typeText("Smoke 随手记内容")
        app.buttons["保存"].tap()
        waitFor(app.staticTexts["Smoke 随手记内容"])

        startNewLog("测量")
        let valueField = app.textFields["数值"]
        valueField.tap()
        valueField.typeText("65.5")
        app.buttons["保存"].tap()
        waitFor(element(containing: "1 次记录"))
        screenshot("Smoke-timeline")

        // 4a. Edit the measurement: 展开 -> row -> editor.
        app.buttons["measurement.group"].tap()
        let row = app.buttons["measurement.row"].firstMatch
        waitFor(row)
        row.tap()
        waitFor(app.navigationBars["编辑记录"])
        let editField = app.textFields["数值"]
        editField.tap()
        editField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 8) + "66")
        app.buttons["保存"].tap()
        waitFor(element(containing: "66kg"))

        // 4b. Delete the encounter from its detail page.
        element(containing: "就诊 · 面诊").tap()
        waitFor(app.navigationBars["详情"])
        app.buttons["删除记录"].tap()
        confirmDelete()
        XCTAssertTrue(element(containing: "就诊 · 面诊").waitForNonExistence(timeout: 5))

        // 5. Kill + relaunch: everything still there.
        relaunch()
        openJourney("Smoke 旅程")
        waitFor(app.staticTexts["Smoke 随手记内容"])
        XCTAssertFalse(element(containing: "就诊 · 面诊").exists)
        app.buttons["measurement.group"].tap()
        waitFor(element(containing: "66kg"))
        screenshot("Smoke-after-relaunch")
    }
}
