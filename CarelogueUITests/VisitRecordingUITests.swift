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

    private func openRecordingMenu() {
        let menu = app.buttons["recording.menu"]
        waitFor(menu)
        XCTAssertEqual(menu.label, t("更多操作", "More"))
        menu.tap()
    }

    /// M7 T47: a finished recording (and its transcript) can be sent out
    /// through the system share sheet — AirDrop, Files.
    func testRecordingCanBeShared() {
        launch(["-uitest-reset", "-uitest-seed-recording"])
        openSeededVisit()

        openRecordingMenu()
        waitFor(app.buttons["recording.share"])
        XCTAssertEqual(app.buttons["recording.share"].label, t("分享录音", "Share Recording"))
        screenshot("T47-recording-menu")
        app.buttons["recording.share"].tap()

        let sheet = app.otherElements["ActivityListView"]
        waitFor(sheet, timeout: 10)
        sleep(1) // let the sheet settle before the screenshot
        screenshot("T47-share-recording")
    }

    /// M7 T47: an English-speaking doctor in a Chinese-language app. The
    /// language with the confident transcript wins, so the visit goes on to
    /// be summarised as usual.
    func testRetranscribeDetectsTheVisitLanguage() {
        launch(["-uitest-reset", "-uitest-seed-recording", "-uitest-fake-transcript", "english",
                "-uitest-fake-ai", "success", "-ai.consent", "granted"])
        openSeededVisit()

        openRecordingMenu()
        app.buttons["recording.retranscribe"].tap()
        let confirm = app.buttons["recording.retranscribe.confirm"]
        waitFor(confirm)
        screenshot("T47-retranscribe-confirm")
        confirm.tap()

        waitFor(app.buttons["recording.summaryLine"], timeout: 20)
        XCTAssertFalse(id("recording.lowConfidence").exists)
    }

    /// M7 T47: unsure in every language — the transcript is kept, the user is
    /// told, and nothing goes to the AI until they ask.
    func testLowConfidenceTranscriptWaitsForTheUser() {
        launch(["-uitest-reset", "-uitest-seed-recording", "-uitest-fake-transcript", "low",
                "-uitest-fake-ai", "success", "-ai.consent", "granted"])
        openSeededVisit()

        openRecordingMenu()
        app.buttons["recording.retranscribe"].tap()
        app.buttons["recording.retranscribe.confirm"].tap()

        waitFor(id("recording.lowConfidence"), timeout: 15)
        XCTAssertTrue(app.buttons["recording.summarize"].exists)
        XCTAssertFalse(app.buttons["recording.summaryLine"].exists)
        screenshot("T47-low-confidence")
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
