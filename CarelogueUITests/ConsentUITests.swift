import XCTest

/// M3 T21: first-use consent sheet (once per device), decline, revoke.
final class ConsentUITests: CarelogueUITestCase {
    private let journeyName = "UITest 孕期"

    // AI is a Carelogue Plus feature (T27); these tests are about the
    // explanation flow, so the subscription is pinned active.
    override func setUpWithError() throws {
        try super.setUpWithError()
        stickyArguments = ["-uitest-subscription", "active"]
    }

    private func id(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    private func openSeededEncounter() {
        openJourney(journeyName)
        element(containing: "UITest 附件就诊").tap()
        waitFor(app.navigationBars["详情"])
        waitFor(id("explain.card"))
    }

    func testShownOnceThenRemembered() {
        launch(["-uitest-reset", "-uitest-seed-attachments", "-uitest-fake-ai", "success"])
        openSeededEncounter()
        app.buttons["explain.button"].tap()

        let accept = app.buttons["consent.accept"]
        waitFor(accept)
        XCTAssertTrue(element(containing: "加密传输 · Encrypted in transit").exists)
        XCTAssertFalse(element(containing: "端到端").exists)
        screenshot("T21-consent-sheet")
        accept.tap()
        waitFor(id("explain.summary"), timeout: 10)

        // Second attachment: no sheet this time.
        app.buttons["explain.attachment.2"].tap()
        app.buttons["explain.button"].tap()
        XCTAssertFalse(accept.waitForExistence(timeout: 2))
        waitFor(id("explain.summary"), timeout: 10)

        // Still remembered after a relaunch.
        relaunch()
        app.terminate()
        launch(["-uitest-fake-ai", "success"])
        openSeededEncounter()
        // The textless striped photo: no sheet, straight to the on-device
        // "no text" error (nothing is sent).
        app.buttons["explain.attachment.1"].tap()
        app.buttons["explain.button"].tap()
        XCTAssertFalse(accept.waitForExistence(timeout: 2))
        waitFor(id("explain.error"), timeout: 10)
        XCTAssertTrue(element(containing: "没有识别到文字").exists)
    }

    func testDeclineSendsNothingAndLocalFeaturesWork() {
        launch(["-uitest-reset", "-uitest-seed-attachments", "-uitest-fake-ai", "count"])
        openSeededEncounter()
        app.buttons["explain.button"].tap()
        let decline = app.buttons["consent.decline"]
        waitFor(decline)
        decline.tap()

        // Nothing explained; card back to idle.
        XCTAssertTrue(app.buttons["consent.accept"].waitForNonExistence(timeout: 3))
        waitFor(app.buttons["explain.button"])
        XCTAssertFalse(id("explain.loading").exists)

        // Local features unaffected: preview an attachment, add a quick note.
        let thumbnail = app.buttons.matching(identifier: "attachment.image").firstMatch
        scrollTo(thumbnail)
        thumbnail.tap()
        waitFor(id("attachment.preview"))
        app.buttons["关闭"].tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        startNewLog("随手记")
        app.textViews.firstMatch.typeText("拒绝 AI 后的随手记")
        app.buttons["保存"].tap()
        waitFor(app.staticTexts["拒绝 AI 后的随手记"])

        // Tapping 解释 again asks again (consent was never given).
        element(containing: "UITest 附件就诊").tap()
        app.buttons["explain.button"].tap()
        waitFor(app.buttons["consent.accept"])
        app.buttons["consent.accept"].tap()
        // First request only now: the fake numbers its replies.
        waitFor(element(containing: "[#1]"), timeout: 10)
    }

    func testRevokeInSettingsDisablesEntry() {
        launch(["-uitest-reset", "-uitest-seed-attachments", "-uitest-fake-ai", "success"])
        openSeededEncounter()
        // Consent through the real sheet (a -ai.consent launch argument
        // would shadow the app's own write when revoking).
        app.buttons["explain.button"].tap()
        app.buttons["consent.accept"].tap()
        waitFor(id("explain.summary"), timeout: 10)

        // Go to Settings and revoke.
        app.navigationBars.buttons.element(boundBy: 0).tap() // timeline
        app.navigationBars.buttons.element(boundBy: 0).tap() // journeys
        button(containing: "档案与设置").tap()
        app.buttons["profile.settings"].tap()
        let revoke = app.buttons["settings.revokeConsent"]
        waitFor(revoke)
        let bottom = app.windows.firstMatch.frame.maxY - 80
        for _ in 0..<5 where revoke.frame.maxY > bottom { app.swipeUp() }
        revoke.tap()
        tapFirstExisting([app.sheets.buttons["撤回同意"], app.buttons["撤回同意"]])
        waitFor(id("settings.consentRevoked"))
        screenshot("T21-settings-revoked")
        XCTAssertFalse(revoke.exists)

        // The report page's AI entry is now disabled.
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["完成"].tap()
        openJourney(journeyName)
        element(containing: "UITest 附件就诊").tap()
        waitFor(id("explain.revoked"))
        XCTAssertFalse(app.buttons["explain.button"].exists)
        screenshot("T21-report-revoked")

        // Re-consent from the report page; the earlier result is still there.
        app.buttons["explain.reconsent"].tap()
        waitFor(app.buttons["consent.accept"])
        app.buttons["consent.accept"].tap()
        waitFor(id("explain.summary"), timeout: 10)
    }
}
