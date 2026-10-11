import XCTest

/// M8 T55 (summary chips) and T56 (target day and progress): generic for any
/// journey; an existing journey with nothing set looks exactly as before.
final class JourneySummaryUITests: CarelogueUITestCase {
    private var progress: XCUIElement { app.otherElements["journey.progress"].exists
        ? app.otherElements["journey.progress"] : app.buttons["journey.progress"] }
    private var chips: XCUIElementQuery { app.descendants(matching: .any).matching(identifier: "journey.chip") }

    private func openEditor() {
        app.buttons["timeline.more"].tap()
        let item = app.buttons["timeline.editSummary"]
        waitFor(item)
        item.tap()
        waitFor(app.navigationBars["概要与目标日"])
    }

    func testPregnancyTargetAndChips() {
        // An existing journey (made before 1.1): no ring, no chips.
        launch(["-uitest-reset", "-uitest-seed-upcoming"])
        openJourney("UITest 复诊")
        XCTAssertFalse(progress.exists)
        XCTAssertEqual(chips.count, 0)

        // Target on: the pregnancy template suggests 预产期; + 血型 adds a slot.
        openEditor()
        flip(app.switches["summary.targetToggle"])
        let label = app.textFields["summary.targetLabel"]
        waitFor(label)
        XCTAssertEqual(label.value as? String, "预产期")
        let bloodType = app.buttons["+ 血型"]
        scrollTo(bloodType)
        bloodType.tap()
        let value = app.textFields.matching(identifier: "summary.itemValue").firstMatch
        waitFor(value)
        value.tap()
        value.typeText("O+")
        screenshot("T55-editor")
        app.buttons["summary.save"].tap()

        // Header: the due-date chip, 血型 O+, and the ring. The default target
        // is a month out, and a pregnancy counts from 40 weeks before it.
        waitFor(element(containing: "血型"))
        XCTAssertEqual(chips.count, 2)
        XCTAssertTrue(element(containing: "预产期").exists)
        waitFor(progress)
        XCTAssertTrue(progress.label.contains("还剩"), progress.label)
        XCTAssertTrue(progress.label.contains("第 3"), "Expected week 3x: \(progress.label)")
        screenshot("T56-header")

        // Persisted.
        relaunch()
        openJourney("UITest 复诊")
        waitFor(progress)
        XCTAssertEqual(chips.count, 2)

        // Clearing the target removes the ring and its chip; 血型 stays.
        openEditor()
        flip(app.switches["summary.targetToggle"])
        app.buttons["summary.save"].tap()
        XCTAssertTrue(progress.waitForNonExistence(timeout: 5))
        waitForCount(chips, 1)

        // Deleting the last item leaves the header as it began.
        openEditor()
        let row = app.textFields.matching(identifier: "summary.itemValue").firstMatch
        scrollTo(row)
        row.swipeLeft()
        tapFirstExisting([app.buttons["Delete"], app.buttons["删除"]])
        app.buttons["summary.save"].tap()
        waitForCount(chips, 0)
    }

    func testCustomJourneyCountsFromItsStart() {
        launch(["-uitest-reset"])
        button(containing: "新建健康旅程").tap()
        let name = app.textFields.firstMatch
        waitFor(name)
        name.typeText("膝盖手术")
        app.buttons["下一步"].tap()
        let custom = app.buttons["自定义"]
        waitFor(custom)
        custom.tap()
        openJourney("膝盖手术")

        openEditor()
        flip(app.switches["summary.targetToggle"])
        let label = app.textFields["summary.targetLabel"]
        waitFor(label)
        XCTAssertEqual(label.value as? String, "手术日")
        app.buttons["summary.save"].tap()

        // Starts today: 0%, about a month to go, no week yet.
        waitFor(progress)
        XCTAssertTrue(progress.label.contains("0%"), progress.label)
        XCTAssertTrue(progress.label.contains("还剩"), progress.label)
        XCTAssertFalse(progress.label.contains("周"), progress.label)
        XCTAssertTrue(element(containing: "手术日").exists)
        screenshot("T56-custom")
    }
}
