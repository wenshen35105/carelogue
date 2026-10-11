import XCTest

/// M8 T54 · Apple Health: connect a journey (the system asks to read only
/// the ticked types), readings come in once, and measurements recorded in
/// Carelogue are written back — and removed again when deleted.
final class HealthUITests: CarelogueUITestCase {
    /// The Health permission sheet is drawn by another process and never
    /// shows up in queries; it is only there the first time per install.
    /// While it covers the app, our own connect button is not hittable —
    /// then answer it by position (Turn On All, then Allow).
    private func allowHealthAccess() {
        sleep(3)
        guard !app.buttons["health.connect"].isHittable else { return }
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.428)).tap()
        sleep(1)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.104)).tap()
        sleep(2)
    }

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

        // Weight + blood pressure are ticked by default; connect.
        app.buttons["health.connect"].tap()
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
        XCTAssertEqual(exported.label, "Exported to Health: 1")
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
}
