import XCTest

/// M7 (1.0.1) editor cards: visit time (T42), measurement notes (T43),
/// location / doctor suggestions (T45).
final class LogEditorUITests: CarelogueUITestCase {
    private let journeyName = "UITest 孕期"

    /// A row's timestamp carries hours and minutes ("10月1日 14:05").
    private let timePattern = NSPredicate(format: "label MATCHES %@", ".*[0-9]{1,2}:[0-9]{2}.*")

    /// T42: the visit editor offers a time, and the timeline shows it.
    func testVisitRecordsATime() {
        launch(["-uitest-reset", "-uitest-seed-measurements"])
        openJourney(journeyName)

        startNewLog("就诊")
        selectChip("面诊")
        let picker = app.datePickers["editor.encounterTime"]
        waitFor(picker)
        // A time button next to the date one; a date-only picker has none.
        let timeButton = picker.buttons.matching(timePattern).firstMatch
        XCTAssertTrue(timeButton.exists, "Visit picker has no time component")

        // Set 14:05 on the time wheels.
        timeButton.tap()
        let wheels = app.pickerWheels
        waitFor(wheels.firstMatch)
        screenshot("T42-editor-time")
        wheels.element(boundBy: 0).adjust(toPickerWheelValue: "14")
        wheels.element(boundBy: 1).adjust(toPickerWheelValue: "05")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1)).tap() // close the popover
        app.buttons["保存"].tap()

        let row = element(containing: "就诊 · 面诊")
        waitFor(row)
        XCTAssertTrue(element(containing: "14:05").exists, "Timeline row lacks the visit time: \(row.label)")
        screenshot("T42-timeline-time")

        row.tap()
        waitFor(app.navigationBars["详情"])
        XCTAssertTrue(element(containing: "14:05").exists)
    }

    /// T43: a measurement takes a note, shown under its row and kept on edit.
    func testMeasurementKeepsANote() {
        launch(["-uitest-reset", "-uitest-seed-measurements"])
        openJourney(journeyName)

        startNewLog("测量")
        let valueField = app.textFields["数值"]
        valueField.tap()
        valueField.typeText("72.5")
        let note = app.textViews["editor.measurementNote"]
        scrollTo(note)
        note.tap()
        note.typeText("饭后散步回来量的")
        screenshot("T43-editor-note")
        app.buttons["保存"].tap()

        app.buttons["measurement.group"].tap()
        let noteText = element(containing: "饭后散步回来量的")
        waitFor(noteText)
        screenshot("T43-row-note")

        // Reopen: the note is still in the editor.
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "饭后散步回来量的")).firstMatch.tap()
        waitFor(app.navigationBars["编辑记录"])
        let reopened = app.textViews["editor.measurementNote"]
        scrollTo(reopened)
        XCTAssertEqual(reopened.value as? String, "饭后散步回来量的")
    }
}
