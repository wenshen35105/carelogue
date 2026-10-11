import XCTest

/// M8 T51: the rating prompt is asked for on the save of the fifth record,
/// then not again for 90 days; Settings always offers the App Store link.
final class ReviewPromptUITests: CarelogueUITestCase {
    private func addQuickNote(_ text: String) {
        startNewLog("随手记")
        app.textViews.firstMatch.typeText(text)
        app.buttons["保存"].tap()
        waitFor(app.staticTexts[text])
        dismissRatingPromptIfShown()
    }

    /// iOS shows the real prompt in development builds; get it out of the way.
    private func dismissRatingPromptIfShown() {
        let notNow = NSPredicate(format: "label IN %@", ["Not Now", "以后", "暂不"])
        for source in [app!, springboard] {
            let button = source.buttons.matching(notNow).firstMatch
            if button.waitForExistence(timeout: 3) {
                screenshot("T51-system-prompt")
                button.tap()
                return
            }
        }
    }

    private func reviewRequests() -> String {
        app.navigationBars.buttons.element(boundBy: 0).tap()   // timeline -> Journeys
        openSettingsPage()
        let label = app.staticTexts["debug.reviewRequests"]
        scrollTo(label)
        let value = label.label
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["完成"].tap()
        return value
    }

    func testAsksOnFifthRecordThenStaysQuiet() {
        // One visit seeded; three more records stay under the threshold.
        launch(["-uitest-reset", "-uitest-seed-upcoming"])
        openJourney("UITest 复诊")
        for index in 2...4 { addQuickNote("评分测试 \(index)") }
        XCTAssertEqual(reviewRequests(), "Review requests: 0")

        // The fifth record asks.
        openJourney("UITest 复诊")
        addQuickNote("评分测试 5")
        XCTAssertEqual(reviewRequests(), "Review requests: 1")

        // The sixth does not: 90 quiet days.
        openJourney("UITest 复诊")
        addQuickNote("评分测试 6")
        XCTAssertEqual(reviewRequests(), "Review requests: 1")

        // 89 days later still quiet; 91 days later it asks again.
        app.terminate()
        launch(["-uitest-review-asked-days-ago", "89"])
        openJourney("UITest 复诊")
        addQuickNote("评分测试 7")
        XCTAssertEqual(reviewRequests(), "Review requests: 1")
        app.terminate()
        launch(["-uitest-review-asked-days-ago", "91"])
        openJourney("UITest 复诊")
        addQuickNote("评分测试 8")
        XCTAssertEqual(reviewRequests(), "Review requests: 2")
    }

    func testSettingsOffersTheAppStoreReview() {
        launch(["-uitest-reset"])
        waitFor(app.navigationBars["Journeys"])
        openSettingsPage()
        let rate = app.links["settings.rateApp"].exists ? app.links["settings.rateApp"] : app.buttons["settings.rateApp"]
        scrollTo(rate)
        XCTAssertTrue(rate.label.contains("去评分"), rate.label)
        screenshot("T51-settings-rate")
    }
}
