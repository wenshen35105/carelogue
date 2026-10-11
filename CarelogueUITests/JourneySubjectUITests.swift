import XCTest

/// M8 T61: a journey says whose health it records. Apple Health connects
/// only on that person's device; an unspecified journey is claimed on first
/// connect; measurements are written back only in a connected journey.
final class JourneySubjectUITests: CarelogueUITestCase {
    private func openEditor() {
        app.buttons["timeline.more"].tap()
        let item = app.buttons["timeline.editSummary"]
        waitFor(item)
        item.tap()
        waitFor(app.navigationBars["概要与目标日"])
    }

    private func openHealthSheet() {
        app.buttons["timeline.more"].tap()
        let item = app.buttons["timeline.health"]
        waitFor(item)
        item.tap()
        waitFor(app.navigationBars["Apple 健康"])
    }

    private func pickSubject(_ option: String) {
        let picker = app.buttons["summary.subject"]
        waitFor(picker)
        picker.tap()
        let choice = app.buttons[option]
        waitFor(choice)
        choice.tap()
    }

    func testUnspecifiedJourneyIsClaimedOnFirstConnect() {
        launch(["-uitest-reset", "-uitest-seed-upcoming"])
        openJourney("UITest 复诊")
        openHealthSheet()
        waitFor(element(containing: "数据属于这台 iPhone 的主人"))

        app.buttons["health.connect"].tap()
        let claim = app.buttons["health.claim"]
        waitFor(claim)
        screenshot("T61-claim")
        claim.tap()
        allowHealthAccess()
        waitFor(app.staticTexts["health.result"], timeout: 10)
        app.buttons["完成"].tap()

        // The journey is now mine.
        openEditor()
        XCTAssertTrue(app.buttons["summary.subject"].label.contains("我自己"), app.buttons["summary.subject"].label)
    }

    func testSomeoneElsesJourneyCannotConnect() {
        launch(["-uitest-reset", "-uitest-seed-upcoming"])
        openJourney("UITest 复诊")
        openEditor()
        pickSubject("其他人")
        let name = app.textFields["summary.subjectName"]
        waitFor(name)
        name.tap()
        name.typeText("小宝")
        screenshot("T61-editor")
        app.buttons["summary.save"].tap()

        // Header says whose journey it is.
        waitFor(element(containing: "记录对象"))
        waitFor(element(containing: "小宝"))
        screenshot("T61-header")

        // Health: explained, and connecting is off on this device.
        openHealthSheet()
        waitFor(app.descendants(matching: .any)["health.someoneElse"])
        XCTAssertFalse(app.buttons["health.connect"].isEnabled)
        screenshot("T61-health-someone-else")
    }

    func testSharedMemberAsSubject() {
        launch(["-uitest-reset", "-uitest-seed-upcoming", "-uitest-fake-share", "active"])
        openJourney("UITest 复诊")
        openEditor()
        pickSubject("太太")
        app.buttons["summary.save"].tap()
        waitFor(element(containing: "太太"))

        openHealthSheet()
        waitFor(app.descendants(matching: .any)["health.someoneElse"])
        waitFor(element(containing: "其他成员录入的测量不会写入你的"))
        XCTAssertFalse(app.buttons["health.connect"].isEnabled)
    }

    /// Writing back follows the journey: a weight recorded in a journey this
    /// device never connected stays out of Health.
    func testWriteBackOnlyInConnectedJourney() {
        launch(["-uitest-reset", "-uitest-seed-upcoming", "-uitest-seed-measurements"])
        // Connect (and claim) the 复诊 journey.
        openJourney("UITest 复诊")
        openHealthSheet()
        app.buttons["health.connect"].tap()
        let claim = app.buttons["health.claim"]
        waitFor(claim)
        claim.tap()
        allowHealthAccess()
        waitFor(app.staticTexts["health.result"], timeout: 10)
        app.buttons["完成"].tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()

        // A weight in the other, unconnected journey: not written.
        openJourney("UITest 孕期")
        startNewLog("测量")
        let value = app.textFields["数值"]
        value.tap()
        value.typeText("70.1")
        app.buttons["保存"].tap()
        waitFor(element(containing: "70.1kg"))
        sleep(2)
        app.navigationBars.buttons.element(boundBy: 0).tap()

        // A weight in the connected one: written.
        openJourney("UITest 复诊")
        startNewLog("测量")
        let mine = app.textFields["数值"]
        mine.tap()
        mine.typeText("62.5")
        app.buttons["保存"].tap()
        waitFor(element(containing: "62.5kg"))
        sleep(2)
        openHealthSheet()
        let exported = app.staticTexts["debug.healthExported"]
        waitFor(exported)
        XCTAssertTrue(exported.label.hasPrefix("Exported to Health: 1"), exported.label)
    }
}
