import XCTest

/// M3 T19 + T20: explain flow and the explanation card's states, driven by
/// the scripted provider (-uitest-fake-ai); one test hits real DeepSeek.
final class ExplainUITests: CarelogueUITestCase {
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

    /// Taps 解释 (and accepts the first-use consent sheet if it shows).
    private func tapExplain(_ button: XCUIElement) {
        button.tap()
        let accept = app.buttons["consent.accept"]
        if accept.waitForExistence(timeout: 1.5) { accept.tap() }
    }

    /// T25 ③: once an attachment is explained, the timeline card carries the
    /// one-line AI summary (Stitch journey_timeline_with_ai_summary).
    func testTimelineShowsAISummaryLine() {
        launch(["-uitest-reset", "-uitest-seed-attachments", "-uitest-fake-ai", "success"])
        openSeededEncounter()
        tapExplain(app.buttons["explain.button"])
        waitFor(id("explain.summary"), timeout: 10)

        tapFirstExisting([app.navigationBars.buttons[journeyName], app.navigationBars.buttons.element(boundBy: 0)])
        let summary = id("timeline.aiSummary")
        waitFor(summary)
        XCTAssertTrue(summary.label.contains("AI 摘要"), "Unexpected label: \(summary.label)")
        XCTAssertTrue(summary.label.contains("血红蛋白"), "Summary text missing: \(summary.label)")
        screenshot("T25-timeline-ai-summary")

        // Cached explanation: the line is still there with no provider at all.
        relaunch()
        openJourney(journeyName)
        waitFor(id("timeline.aiSummary"))
    }

    func testStatesActionsAndPersistence() {
        launch(["-uitest-reset", "-uitest-seed-attachments", "-uitest-fake-ai", "slow"])
        openSeededEncounter()

        // 1. Not explained yet.
        let explain = app.buttons["explain.button"]
        waitFor(explain)
        screenshot("T20-state-idle")

        // 2. Generating.
        tapExplain(explain)
        waitFor(id("explain.loading"))
        screenshot("T20-state-generating")

        // 4. Explained: summary, terms, questions, disclaimer, actions.
        waitFor(id("explain.summary"), timeout: 10)
        XCTAssertTrue(element(containing: "血红蛋白 112 g/L").exists)
        XCTAssertGreaterThanOrEqual(app.buttons.matching(identifier: "explain.term").count, 3)
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "explain.question").count, 3)
        XCTAssertTrue(element(containing: "不能替代医生的诊断").exists)
        sleep(1) // let the state cross-fade finish before the screenshot
        screenshot("T20-state-explained")

        // Term chips: one open at a time.
        app.buttons.matching(identifier: "explain.term").element(boundBy: 0).tap()
        waitFor(id("explain.termDetail"))
        XCTAssertTrue(element(containing: "运送氧气").exists)
        app.buttons.matching(identifier: "explain.term").element(boundBy: 1).tap()
        waitFor(element(containing: "免疫细胞数量"))
        XCTAssertFalse(element(containing: "运送氧气").exists)

        // Copy.
        app.buttons["explain.copy"].tap()
        waitFor(button(containing: "已复制"))

        // Collapse / expand.
        app.buttons["explain.collapse"].tap()
        waitFor(app.buttons["explain.expand"])
        XCTAssertFalse(id("explain.question").exists)
        app.buttons["explain.expand"].tap()
        waitFor(id("explain.question"))

        // Other attachments are independent (exclusive chips): the PDF is unexplained.
        app.buttons["explain.attachment.2"].tap()
        waitFor(app.buttons["explain.button"])
        app.buttons["explain.attachment.0"].tap()
        waitFor(id("explain.summary"))
        XCTAssertEqual(app.buttons["explain.attachment.0"].value as? String, "已解释")
        XCTAssertNotEqual(app.buttons["explain.attachment.2"].value as? String, "已解释")

        // Cached result survives a relaunch, with no provider at all.
        relaunch()
        openSeededEncounter()
        waitFor(id("explain.summary"))
    }

    func testFailureAndRetry() {
        launch(["-uitest-reset", "-uitest-seed-attachments", "-uitest-fake-ai", "fail"])
        openSeededEncounter()
        tapExplain(app.buttons["explain.button"])
        waitFor(id("explain.error"), timeout: 10)
        XCTAssertTrue(element(containing: "无法解释，请重试").exists)
        XCTAssertTrue(element(containing: "请求超时").exists)
        screenshot("T20-state-failed")

        app.buttons["explain.retry"].tap()
        waitFor(id("explain.loading"))
        waitFor(id("explain.error"), timeout: 10)

        // Nothing was cached: after a relaunch the card is back to idle.
        relaunch()
        openSeededEncounter()
        waitFor(app.buttons["explain.button"])
    }

    func testInvalidReplyIsNotCached() {
        launch(["-uitest-reset", "-uitest-seed-attachments", "-uitest-fake-ai", "invalid"])
        openSeededEncounter()
        tapExplain(app.buttons["explain.button"])
        waitFor(id("explain.error"), timeout: 10)
        XCTAssertTrue(element(containing: "没有得到可用的解释").exists)
    }

    func testReExplainWithinFiveMinutesSendsNoRequest() {
        launch(["-uitest-reset", "-uitest-seed-attachments", "-uitest-fake-ai", "count"])
        openSeededEncounter()
        tapExplain(app.buttons["explain.button"])
        waitFor(element(containing: "[#1]"), timeout: 10)

        app.buttons["explain.reexplain"].tap()
        waitFor(id("explain.notice"))
        XCTAssertTrue(element(containing: "[#1]").exists)
        XCTAssertFalse(element(containing: "[#2]").exists)
    }

    /// T27: with a subscription but no reachable relay, the card explains
    /// itself instead of hanging or crashing (the key-based variant of this
    /// test went away with BYOK).
    func testUnreachableServiceShowsFriendlyError() {
        launch(["-uitest-reset", "-uitest-seed-attachments",
                "-ai.serverURL", "http://127.0.0.1:9"])
        openSeededEncounter()
        tapExplain(app.buttons["explain.button"])
        waitFor(id("explain.error"), timeout: 20)
        XCTAssertTrue(app.buttons["explain.retry"].exists)
        XCTAssertTrue(element(containing: "附件和记录都不受影响").exists)
    }

    func testAIOffReplacesCard() {
        launch(["-uitest-reset", "-uitest-seed-attachments", "-ai.enabled", "NO"])
        openJourney(journeyName)
        element(containing: "UITest 附件就诊").tap()
        waitFor(id("explain.disabled"))
        XCTAssertFalse(app.buttons["explain.button"].exists)
        screenshot("T20-state-ai-off")
    }

    func testLongTextLayout() {
        launch(["-uitest-reset", "-uitest-seed-attachments", "-uitest-fake-ai", "long"])
        openSeededEncounter()
        tapExplain(app.buttons["explain.button"])
        waitFor(id("explain.summary"), timeout: 10)
        let card = id("explain.card")
        XCTAssertLessThanOrEqual(card.frame.maxX, app.windows.firstMatch.frame.maxX)
        app.swipeUp()
        screenshot("T20-long-text")
    }

    /// Real DeepSeek round trip on the seeded lab-report photo. Runs only
    /// with DEEPSEEK_API_KEY (see scripts/ui-test.sh).
    func testRealExplain() throws {
        guard let key = ProcessInfo.processInfo.environment["DEEPSEEK_API_KEY"], !key.isEmpty else {
            throw XCTSkip("DEEPSEEK_API_KEY not set")
        }
        app.launchEnvironment["UITEST_API_KEY"] = key
        launch(["-uitest-reset", "-uitest-seed-attachments"])
        openSeededEncounter()
        tapExplain(app.buttons["explain.button"])
        XCTAssertTrue(id("explain.summary").waitForExistence(timeout: 90),
                      "Real explain failed: \(id("explain.errorMessage").label)")
        sleep(1)
        screenshot("T20-real-explained")
    }
}
