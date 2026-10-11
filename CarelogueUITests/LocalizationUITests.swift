import XCTest

/// M3 T16: English UI shows no Chinese copy (user data excepted); Chinese UI
/// keeps the side-by-side "中文 English" style.
final class LocalizationUITests: CarelogueUITestCase {
    /// Seeded user data — allowed to stay Chinese in the English UI.
    private let userData = ["UITest 孕期", "UITest 附件就诊", "UITest 复诊", "UITest 叶酸片"]

    private func assertNoChinese(on screen: String, file: StaticString = #filePath, line: UInt = #line) {
        let labels = [app.staticTexts, app.buttons, app.navigationBars, app.textFields]
            .flatMap { $0.allElementsBoundByIndex.map(\.label) }
        let offending = labels.filter { label in
            var stripped = label
            for data in userData { stripped = stripped.replacingOccurrences(of: data, with: "") }
            return stripped.range(of: "\\p{Han}", options: .regularExpression) != nil
        }
        XCTAssertEqual(offending, [], "Chinese copy on \(screen)", file: file, line: line)
    }

    func testEnglishUIHasNoChineseCopy() {
        language = "en"
        launch(["-uitest-reset", "-uitest-seed-measurements", "-uitest-seed-attachments"])

        waitFor(app.navigationBars["Journeys"])
        waitFor(element(containing: "Profile & Settings"))
        assertNoChinese(on: "Journey list")
        screenshot("T16-en-journeys")

        app.staticTexts["UITest 孕期"].tap()
        waitFor(app.buttons["New Entry"])
        app.buttons["measurement.group"].tap()
        waitFor(app.buttons["All 24"])
        assertNoChinese(on: "Timeline")
        screenshot("T16-en-timeline")

        app.buttons["View Chart"].tap()
        waitFor(app.navigationBars["Trends"])
        assertNoChinese(on: "Chart")
        app.buttons["Done"].tap()

        element(containing: "UITest 附件就诊").tap()
        waitFor(app.navigationBars["Details"])
        waitFor(element(containing: "Attachments (3)"))
        assertNoChinese(on: "Log detail")
        screenshot("T16-en-detail")

        app.buttons["Edit"].tap()
        waitFor(app.navigationBars["Edit Entry"])
        waitFor(app.buttons["Blood Test"])
        assertNoChinese(on: "Editor")
        app.buttons["Cancel"].tap()

        app.navigationBars.buttons.element(boundBy: 0).tap() // back to timeline
        app.buttons["New Entry"].tap()
        waitFor(app.buttons["Quick Note"])
        app.buttons["Quick Note"].tap()
        waitFor(app.navigationBars["New Entry"])
        waitFor(app.buttons["Symptom"])
        assertNoChinese(on: "Quick note editor")
    }

    /// M8 T52/T53: the reminder section of a visit and the medication
    /// screens, in English.
    func testEnglishRemindersHaveNoChineseCopy() {
        language = "en"
        launch(["-uitest-reset", "-uitest-seed-upcoming", "-uitest-seed-medication-soon"])
        waitFor(app.navigationBars["Journeys"])
        let entry = app.buttons["home.medications"]
        scrollTo(entry)
        entry.tap()
        waitFor(app.buttons["medication.take"])
        assertNoChinese(on: "Medications")
        screenshot("T53-en-medications")
        app.buttons["medications.add"].tap()
        waitFor(app.navigationBars["Add Medication"])
        assertNoChinese(on: "Medication editor")
        app.buttons["Cancel"].tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()

        app.staticTexts["UITest 复诊"].tap()
        element(containing: "In-Person").tap()
        waitFor(app.navigationBars["Details"])
        app.buttons["Edit"].tap()
        let toggle = app.switches["editor.reminderToggle"]
        scrollTo(toggle)
        flip(toggle)
        allowNotificationsIfAsked()
        waitFor(element(containing: "1 day before"))
        assertNoChinese(on: "Visit reminder")
        screenshot("T52-en-visit-editor")
    }

    /// M8 T55 / T56: the summary editor and the header, in English.
    func testEnglishJourneySummaryHasNoChineseCopy() {
        language = "en"
        launch(["-uitest-reset", "-uitest-seed-upcoming"])
        app.staticTexts["UITest 复诊"].tap()
        app.buttons["timeline.more"].tap()
        app.buttons["timeline.editSummary"].tap()
        let toggle = app.switches["summary.targetToggle"]
        waitFor(toggle)
        flip(toggle)
        waitFor(app.textFields["summary.targetLabel"])
        assertNoChinese(on: "Summary editor")
        app.buttons["summary.save"].tap()
        waitFor(element(containing: "days to go"))
        assertNoChinese(on: "Timeline header")
        screenshot("T56-en-header")
    }

    func testEnglishSettingsHaveNoChineseCopy() {
        language = "en"
        launch(["-uitest-reset"])
        waitFor(app.navigationBars["Journeys"])
        button(containing: "Profile & Settings").tap()
        waitFor(app.navigationBars["Profile"])
        assertNoChinese(on: "Profile")
        app.buttons["profile.settings"].tap()
        waitFor(app.staticTexts["Settings"])
        assertNoChinese(on: "Settings")
        screenshot("T18-settings-en")

        app.swipeUp()
        waitFor(app.buttons["settings.eraseAll"])
        assertNoChinese(on: "Settings (data management)")
        screenshot("T25-settings-data-en")
    }

    func testChineseUIKeepsBilingualStyle() {
        launch(["-uitest-reset", "-uitest-seed-attachments"])
        waitFor(app.navigationBars["Journeys"])
        waitFor(app.staticTexts["档案与设置"])
        waitFor(app.staticTexts["Profile & Settings"])
        waitFor(element(containing: "进行中 Active"))
        screenshot("T16-zh-journeys")

        openJourney("UITest 孕期")
        waitFor(element(containing: "就诊 · 验血"))
        waitFor(element(containing: "(Blood Test)"))
    }
}
