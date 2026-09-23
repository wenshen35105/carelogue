import XCTest

/// Settings page: the AI switch, the subscription card (T28) and 数据管理.
final class SettingsUITests: CarelogueUITestCase {
    func openSettings() {
        waitFor(app.navigationBars["Journeys"])
        button(containing: "档案与设置").tap()
        let entry = app.buttons["profile.settings"]
        waitFor(entry)
        entry.tap()
        waitFor(app.staticTexts["设置 Settings"])
    }

    /// T28: the AI switch still persists, and the API-key rows are gone for
    /// good — a subscription is what unlocks AI now.
    func testAISwitchPersistsAndKeyRowsAreGone() {
        launch(["-uitest-reset"])
        openSettings()

        XCTAssertFalse(app.buttons["settings.changeKey"].exists, "BYOK key row should be gone")
        XCTAssertFalse(app.descendants(matching: .any)["settings.maskedKey"].exists)
        XCTAssertFalse(app.buttons["settings.testConnection"].exists)

        let toggle = app.switches["settings.aiToggle"]
        XCTAssertEqual(toggle.value as? String, "1")
        toggle.switches.firstMatch.tap()
        XCTAssertEqual(toggle.value as? String, "0")
        screenshot("T28-settings")

        relaunch()
        openSettings()
        XCTAssertEqual(app.switches["settings.aiToggle"].value as? String, "0")
    }

    /// T28: subscribed — status, renewal date, manage and restore.
    func testSubscriptionCardWhenSubscribed() {
        stickyArguments = ["-uitest-subscription", "active"]
        launch(["-uitest-reset"])
        openSettings()

        waitFor(element(containing: "订阅中 · Active"))
        XCTAssertTrue(element(containing: "下次续费").exists)
        XCTAssertTrue(app.links["settings.manageSubscription"].exists
                      || app.buttons["settings.manageSubscription"].exists)
        XCTAssertTrue(app.buttons["settings.restore"].exists)
        XCTAssertFalse(app.buttons["settings.openPaywall"].exists)
        screenshot("T28-settings-subscribed")

        // Both policies are reachable from inside the app (App Store review).
        // A SwiftUI Link surfaces as a link or a button depending on the run,
        // so accept either — the point is that it is on the page.
        app.swipeUp()
        app.swipeUp()
        for identifier in ["settings.privacyPolicy", "settings.terms"] {
            let link = app.links[identifier]
            let button = app.buttons[identifier]
            XCTAssertTrue(link.waitForExistence(timeout: 3) || button.exists,
                          "Missing legal link: \(identifier)")
        }
    }

    /// T28: not subscribed — the card offers the paywall instead of Manage.
    func testSubscriptionCardWhenNotSubscribed() {
        stickyArguments = ["-uitest-subscription", "none"]
        launch(["-uitest-reset"])
        openSettings()

        waitFor(element(containing: "未订阅 · Not subscribed"))
        let openPaywall = app.buttons["settings.openPaywall"]
        waitFor(openPaywall)
        openPaywall.tap()
        waitFor(app.descendants(matching: .any)["paywall"])
        screenshot("T28-settings-paywall")
    }

    /// T25 ②: 清空所有数据 removes every journey, record and attachment, and
    /// the store stays empty after a relaunch.
    func testEraseAllData() {
        launch(["-uitest-reset", "-uitest-seed-measurements", "-uitest-seed-attachments"])
        waitFor(app.staticTexts["UITest 孕期"])

        // Profile content counts as data too, and this page stays in the
        // stack under Settings while the wipe runs.
        button(containing: "档案与设置").tap()
        let allergyField = app.textViews.element(boundBy: 0)
        waitFor(allergyField)
        allergyField.tap()
        allergyField.typeText("花生")
        app.buttons["profile.settings"].tap()
        waitFor(app.staticTexts["设置 Settings"])

        let erase = app.buttons["settings.eraseAll"]
        waitFor(erase)
        if !erase.isHittable { app.swipeUp() }
        erase.tap()

        // The dialog names what is about to go. (The row's own label is the
        // whole card, so an exact match only hits the dialog's button.)
        let confirm = app.buttons["清空所有数据"]
        waitFor(confirm)
        XCTAssertTrue(element(containing: "段旅程").exists, "Dialog does not say what will be deleted")
        screenshot("T25-erase-confirm")
        confirm.tap()

        let result = app.descendants(matching: .any)["settings.eraseResult"]
        waitFor(result)
        XCTAssertTrue(result.label.contains("已清空"), "Unexpected summary: \(result.label)")
        screenshot("T25-erase-done")

        // Nothing left behind, before or after a relaunch — including the
        // profile text this page is still holding in memory.
        app.navigationBars.buttons.element(boundBy: 0).tap()
        waitFor(app.navigationBars["档案 · Profile"])
        XCTAssertEqual(app.textViews.element(boundBy: 0).value as? String, "")
        tapFirstExisting([app.navigationBars.buttons["完成"], app.buttons["完成"]])
        XCTAssertFalse(app.staticTexts["UITest 孕期"].exists)
        relaunch()
        waitFor(app.navigationBars["Journeys"])
        XCTAssertFalse(app.staticTexts["UITest 孕期"].waitForExistence(timeout: 3))
        button(containing: "档案与设置").tap()
        waitFor(app.navigationBars["档案 · Profile"])
        XCTAssertEqual(app.textViews.element(boundBy: 0).value as? String, "")
    }

}
