import XCTest

/// Journey-level actions in the list (M7 T50: delete).
final class JourneyUITests: CarelogueUITestCase {
    private let journeyName = "UITest 孕期"

    /// Swipe → 删除 → confirm: the journey and its entries are gone, and stay
    /// gone after a relaunch.
    func testJourneyCanBeDeleted() {
        launch(["-uitest-reset", "-uitest-seed-visit"])
        waitFor(app.navigationBars["Journeys"])

        let card = element(containing: journeyName)
        waitFor(card)
        card.swipeLeft()
        let delete = app.buttons[t("删除", "Delete")]
        waitFor(delete)
        screenshot("T50-swipe-actions")
        delete.tap()

        let confirm = app.buttons[t("删除旅程", "Delete Journey")]
        waitFor(confirm)
        XCTAssertTrue(element(containing: t("无法恢复", "can't be undone")).exists)
        screenshot("T50-delete-confirm")
        confirm.tap()

        XCTAssertTrue(card.waitForNonExistence(timeout: 5))
        relaunch()
        waitFor(app.navigationBars["Journeys"])
        XCTAssertFalse(element(containing: journeyName).exists)
    }

    /// Cancelling the dialog keeps everything.
    func testCancellingKeepsTheJourney() {
        launch(["-uitest-reset", "-uitest-seed-visit"])
        let card = element(containing: journeyName)
        waitFor(card)
        card.swipeLeft()
        app.buttons[t("删除", "Delete")].tap()
        let cancel = app.buttons[t("取消", "Cancel")]
        waitFor(cancel)
        cancel.tap()
        XCTAssertTrue(card.waitForExistence(timeout: 3))
    }
}
