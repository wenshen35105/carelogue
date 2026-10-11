import XCTest

/// M8 T54 · Apple Health: connect a journey (the system asks to read only
/// the ticked types), readings come in once, and measurements recorded in
/// Carelogue are written back — and removed again when deleted.
final class HealthUITests: CarelogueUITestCase {
    private func openHealthSheet() {
        app.buttons["timeline.more"].tap()
        let item = app.buttons["timeline.health"]
        waitFor(item)
        item.tap()
        waitFor(app.navigationBars["Apple 健康"])
    }

    func testConnectImportsOnceAndWritesBack() {
        launch(["-uitest-reset", "-uitest-seed-upcoming", "-uitest-seed-health"])
        openJourney("UITest 复诊")
        openHealthSheet()
        screenshot("T54-link-sheet")

        // Weight + blood pressure are ticked by default; connect — the
        // journey says nothing about whose it is yet, so claim it (T61).
        app.buttons["health.connect"].tap()
        let claim = app.buttons["health.claim"]
        waitFor(claim)
        claim.tap()
        allowHealthAccess()
        let result = app.staticTexts["health.result"]
        waitFor(result, timeout: 10)
        XCTAssertTrue(result.label.contains("4"), "Expected 3 weights + 1 blood pressure: \(result.label)")
        screenshot("T54-imported")

        // Connecting again finds nothing new.
        app.buttons["health.connect"].tap()
        let nothingNew = NSPredicate(format: "label CONTAINS %@", "没有新的读数")
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: nothingNew, object: result)], timeout: 8),
                       .completed, result.label)
        app.buttons["完成"].tap()

        // The readings are measurements in the journey now: 3 weights, 1 BP.
        let group = app.buttons["measurement.group"]
        waitFor(group)
        group.tap()
        waitFor(app.buttons["全部 4"])
        XCTAssertTrue(app.buttons["体重 3"].exists)
        XCTAssertTrue(element(containing: "117/76mmHg").exists)

        // Write-back: a weight recorded here lands in Health…
        startNewLog("测量")
        let value = app.textFields["数值"]
        value.tap()
        value.typeText("62.5")
        app.buttons["保存"].tap()
        waitFor(app.buttons["全部 5"])
        sleep(2)
        openHealthSheet()
        let exported = app.staticTexts["debug.healthExported"]
        waitFor(exported)
        XCTAssertTrue(exported.label.hasPrefix("Exported to Health: 1"), exported.label)
        app.buttons["完成"].tap()

        // …and leaves it again when deleted.
        let rows = app.buttons.matching(identifier: "measurement.row")
        let mine = rows.matching(NSPredicate(format: "label CONTAINS %@", "62.5kg")).firstMatch
        waitFor(mine)
        mine.tap()
        waitFor(app.navigationBars["编辑记录"])
        app.buttons["删除记录"].tap()
        confirmDelete()
        waitFor(app.buttons["全部 4"])
        sleep(2)
        openHealthSheet()
        waitFor(exported)
        XCTAssertEqual(exported.label, "Exported to Health: 0")
    }

    // MARK: - Units, hand-typed twins, import start

    private func connectClaiming() {
        app.buttons["health.connect"].tap()
        let claim = app.buttons["health.claim"]
        if claim.waitForExistence(timeout: 3) { claim.tap() }
        allowHealthAccess()
        waitFor(app.staticTexts["health.result"], timeout: 10)
    }

    /// A weight in the measurement editor, with its unit typed over "kg".
    private func addWeight(_ value: String, unit: String) {
        startNewLog("测量")
        let field = app.textFields["数值"]
        field.tap()
        field.typeText(value)
        let unitField = app.textFields["单位（如 kg）"]
        unitField.tap()
        unitField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 4) + unit)
        app.buttons["保存"].tap()
        waitFor(element(containing: "\(value)\(unit)"))
        sleep(2)
    }

    /// 140 lb goes to Health as 63.5 kg; a unit Carelogue doesn't know is
    /// not written at all.
    func testWriteBackConvertsUnitsAndSkipsUnknownOnes() {
        launch(["-uitest-reset", "-uitest-seed-upcoming"])
        openJourney("UITest 复诊")
        openHealthSheet()
        connectClaiming()
        app.buttons["完成"].tap()

        addWeight("140", unit: "lb")
        addWeight("10", unit: "stone")
        openHealthSheet()
        let exported = app.staticTexts["debug.healthExported"]
        waitFor(exported)
        XCTAssertEqual(exported.label, "Exported to Health: 1 · 63.5")
    }

    /// A journey kept in pounds gets Health's readings in pounds, and a
    /// reading already typed in by hand (136.7 lb ≈ the scale's 62.0 kg,
    /// minutes apart) is not imported a second time.
    func testImportUsesTheJourneysUnitAndSkipsHandTypedTwins() {
        launch(["-uitest-reset", "-uitest-seed-upcoming", "-uitest-seed-health"])
        openJourney("UITest 复诊")
        addWeight("136.7", unit: "lb")
        openHealthSheet()
        connectClaiming()
        let result = app.staticTexts["health.result"]
        XCTAssertTrue(result.label.contains("3"), "2 weights + 1 blood pressure, the twin skipped: \(result.label)")
        app.buttons["完成"].tap()

        app.buttons["measurement.group"].tap()
        waitFor(app.buttons["体重 3"])
        XCTAssertTrue(element(containing: "134.9lb").exists)
        XCTAssertTrue(element(containing: "135.8lb").exists)
        screenshot("T54-import-in-lb")
    }

    /// Reading from earlier than the journey's start picks up what came
    /// before it.
    func testEarlierImportStartReachesBack() {
        launch(["-uitest-reset", "-uitest-seed-upcoming", "-uitest-seed-health"])
        openJourney("UITest 复诊")
        openHealthSheet()
        connectClaiming()
        let result = app.staticTexts["health.result"]
        XCTAssertTrue(result.label.contains("4"), result.label)

        let start = app.buttons["health.start"]
        start.tap()
        let earlier = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "提前 3 个月")).firstMatch
        waitFor(earlier)
        earlier.tap()
        app.buttons["health.connect"].tap()
        let one = NSPredicate(format: "label CONTAINS %@", "已导入 1 条")
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: one, object: result)], timeout: 10),
                       .completed, result.label)
        screenshot("T54-import-start")
    }
}
