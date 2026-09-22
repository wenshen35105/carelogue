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
