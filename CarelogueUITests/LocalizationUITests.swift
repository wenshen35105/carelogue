import XCTest

/// M3 T16: English UI shows no Chinese copy (user data excepted); Chinese UI
/// keeps the side-by-side "中文 English" style.
final class LocalizationUITests: CarelogueUITestCase {
    /// Seeded user data — allowed to stay Chinese in the English UI.
    private let userData = ["UITest 孕期", "UITest 附件就诊"]

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
