import XCTest

/// M3 T18: settings page, Keychain-backed API key, AI switch.
final class SettingsUITests: CarelogueUITestCase {
    func openSettings() {
        waitFor(app.navigationBars["Journeys"])
        button(containing: "档案与设置").tap()
        let entry = app.buttons["profile.settings"]
        waitFor(entry)
        entry.tap()
        waitFor(app.staticTexts["设置 Settings"])
    }

    func testKeyPersistsAndSwitchTurnsOff() {
        launch(["-uitest-reset"])
        openSettings()
        waitFor(element(containing: "未配置 Not set"))

        app.buttons["settings.changeKey"].tap()
        let field = app.secureTextFields["settings.keyField"]
        waitFor(field)
        field.typeText("sk-uitest-00001234abcd")
        app.buttons["保存"].tap()
        waitFor(app.staticTexts["sk-••••••••abcd"])
        waitFor(element(containing: "已配置 Connected"))

        let toggle = app.switches["settings.aiToggle"]
        XCTAssertEqual(toggle.value as? String, "1")
        toggle.switches.firstMatch.tap()
        XCTAssertEqual(toggle.value as? String, "0")
        screenshot("T18-settings")

        // Keychain + preference survive a kill / relaunch.
        relaunch()
        openSettings()
        waitFor(app.staticTexts["sk-••••••••abcd"])
        XCTAssertEqual(app.switches["settings.aiToggle"].value as? String, "0")
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

    /// Real DeepSeek round trip. Runs only when scripts/ui-test.sh is given
    /// DEEPSEEK_API_KEY (passed to the runner as TEST_RUNNER_DEEPSEEK_API_KEY).
    func testRealConnection() throws {
        guard let key = ProcessInfo.processInfo.environment["DEEPSEEK_API_KEY"], !key.isEmpty else {
            throw XCTSkip("DEEPSEEK_API_KEY not set")
        }
        app.launchEnvironment["UITEST_API_KEY"] = key
        launch(["-uitest-reset"])
        openSettings()
        waitFor(element(containing: "已配置 Connected"))
        app.buttons["settings.testConnection"].tap()
        let ok = element(containing: "连接正常")
        XCTAssertTrue(ok.waitForExistence(timeout: 60), "Connection test failed: \(app.descendants(matching: .any)["settings.testResult"].label)")
    }
}
