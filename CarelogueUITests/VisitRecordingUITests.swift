import XCTest

/// 面诊录音 + 我的疑问 (T32).
///
/// Capturing audio itself is a device thing — the simulator has no consulting
/// room and no on-device speech model — so the card is driven from a seeded
/// recording whose transcript is already in place, and the AI half runs
/// against the scripted provider. What this covers is everything between:
/// the card's three faces, summarising, the questions list, the translation,
/// and the large-type hand-off.
final class VisitRecordingUITests: CarelogueUITestCase {
    override func setUpWithError() throws {
        try super.setUpWithError()
        stickyArguments = ["-uitest-subscription", "active"]
    }

    private func id(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    private func openSeededVisit() {
        openJourney("UITest 孕期")
        element(containing: "UITest 面诊录音").tap()
        waitFor(app.navigationBars[t("详情", "Details")])
        waitFor(id("recording.card"))
    }

    /// Nothing recorded yet: the invitation to record, and the questions entry
    /// that explicitly does not need one.
    func testEmptyCardOffersRecordingAndQuestions() {
        launch(["-uitest-reset", "-uitest-seed-visit"])
        openSeededVisit()

        waitFor(app.buttons["recording.start"])
        XCTAssertTrue(app.buttons["recording.questions"].exists)
        XCTAssertTrue(element(containing: "提问无需录音").exists)
        // The privacy wording is the one thing that must not drift (T32).
        XCTAssertTrue(element(containing: "音频不进 AI").exists)
        screenshot("T32-recording-empty")
    }

    /// A finished recording: play control, duration, and the summarise step
    /// that sends only the transcript.
    func testRecordedVisitSummarises() {
        launch(["-uitest-reset", "-uitest-seed-recording", "-uitest-fake-ai", "slow",
                "-ai.consent", "granted"])
        openSeededVisit()

        waitFor(app.buttons["recording.play"])
        XCTAssertTrue(element(containing: "已录音").exists)
        screenshot("T32-recording-recorded")

        app.buttons["recording.summarize"].tap()
        waitFor(id("recording.working"))
        waitFor(app.buttons["recording.summaryLine"], timeout: 20)
        screenshot("T32-recording-summarised")

        app.buttons["recording.summaryLine"].tap()
        waitFor(id("summary.page"))
        waitFor(id("summary.said"))
        XCTAssertTrue(id("summary.keyPoints").exists)
        XCTAssertTrue(id("summary.followUps").exists)
        XCTAssertTrue(element(containing: "AI 整理，可能有遗漏").exists)
        screenshot("T32-visit-summary")

        // The summary is saved on the visit, so it survives a relaunch — no
        // "存入病历" button, by design.
        relaunch()
        openSeededVisit()
        waitFor(app.buttons["recording.summaryLine"])
    }

    /// 我的疑问: write in Chinese, translate, hand the phone over.
    func testQuestionsTranslateAndHandOff() {
        launch(["-uitest-reset", "-uitest-seed-visit", "-uitest-fake-ai", "success",
                "-ai.consent", "granted"])
        openSeededVisit()

        app.buttons["recording.questions"].tap()
        waitFor(id("questions.page"))

        let field = id("questions.field")
        waitFor(field)
        field.tap()
        field.typeText("血糖偏高需要控制饮食吗？")
        app.buttons["questions.add"].tap()
        waitFor(element(containing: "血糖偏高需要控制饮食吗？"))
        XCTAssertTrue(element(containing: "还没有英文版").exists)
        screenshot("T32-questions-written")

        app.buttons["questions.translate"].tap()
        waitFor(element(containing: "ENGLISH NOTE"), timeout: 15)
        waitFor(element(containing: "Do I need to watch my diet"))
        screenshot("T32-questions-translated")

        app.buttons["questions.present"].tap()
        waitFor(id("handoff.page"))
        waitFor(element(containing: "Do I need to watch my diet"))
        screenshot("T32-questions-handoff")
        app.buttons["handoff.close"].tap()

        // Questions belong to the visit, not to the session.
        waitFor(id("questions.page"))
        relaunch()
        openSeededVisit()
        app.buttons["recording.questions"].tap()
        waitFor(element(containing: "血糖偏高需要控制饮食吗？"))
    }

    /// The questions list is reachable with no recording and no subscription —
    /// only the translation is behind the AI gate.
    func testQuestionsWorkWithoutSubscription() {
        stickyArguments = ["-uitest-subscription", "none"]
        launch(["-uitest-reset", "-uitest-seed-visit"])
        openSeededVisit()

        app.buttons["recording.questions"].tap()
        waitFor(id("questions.page"))
        let field = id("questions.field")
        waitFor(field)
        field.tap()
        field.typeText("下次产检要带什么？")
        app.buttons["questions.add"].tap()
        waitFor(element(containing: "下次产检要带什么？"))
    }
}
