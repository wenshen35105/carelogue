import XCTest

/// App Store Connect screenshots for the 1.0 listing (T41), shot on the
/// iPhone 13 Pro Max simulator (1284 × 2778 — ASC's 6.5" tier). Same
/// `-uitest-seed-demo` store as the documentation shots, so the listing
/// shows a Journey in full swing, never fixture data.
///
/// Two listings, one set of steps: this class shoots the zh-Hans set, and
/// `ASCScreenshotEnglishUITests` below re-runs the same tests in English
/// (the demo store follows the launch language). Run each on the 13 Pro Max
/// simulator and collect into the submission folder:
///
///   SIM_ID=<13 Pro Max udid> SCREENSHOT_DIR=$PWD/build/asc-zh \
///     scripts/ui-test.sh -only-testing:CarelogueUITests/ASCScreenshotUITests
///   cp build/asc-zh/*.png docs/appstore-submission/screenshots/iphone-6.5/zh-Hans/
///   (same with ASCScreenshotEnglishUITests → iphone-6.5/en-CA/)
///
/// The timeline shot pins `-uitest-fake-share active`, so it includes the
/// 1.0 share feature: the 共享中 marker and the share entry in the toolbar.
class ASCScreenshotUITests: CarelogueUITestCase {
    private var journeyName: String { t("孕期档案", "Our First Baby") }
    private var reportCardText: String { t("就诊 · 验血", "Visit · Blood Test") }
    private var details: String { t("详情", "Details") }

    /// The shots that show AI results need the unlocked layout.
    override func setUpWithError() throws {
        try super.setUpWithError()
        stickyArguments = ["-uitest-subscription", "active"]
    }

    private func settle(_ seconds: TimeInterval = 0.8) {
        RunLoop.current.run(until: Date.now.addingTimeInterval(seconds))
    }

    private func backToTimeline() {
        tapFirstExisting([app.navigationBars.buttons[journeyName],
                          app.navigationBars.buttons.element(boundBy: 0)])
        waitFor(app.buttons[t("新建记录", "New Entry")])
    }

    /// Shots 01–06: journeys, timeline (with the share feature), the
    /// explained report, the recording card, the visit summary, and the
    /// translated questions.
    func testMainScreens() {
        // Signed in to iCloud, as most users are: the recording privacy note
        // then describes the synced state rather than the device-only one.
        launch(["-uitest-reset", "-uitest-seed-demo", "-uitest-fake-share", "active",
                "-uitest-icloud-account"])

        // 01 · 旅程列表 — the door to the app: two journeys, one running.
        waitFor(app.navigationBars["Journeys"])
        waitFor(app.staticTexts[journeyName])
        waitFor(app.staticTexts[t("拔智齿记录", "Wisdom Tooth")])
        settle()
        screenshot("01-journeys")

        // 02 · 时间线 — upcoming appointment, cards, AI summary line, and
        // the 1.0 share marker in the header.
        openJourney(journeyName)
        waitFor(element(containing: t("下次", "Next")))
        waitFor(app.descendants(matching: .any)["timeline.aiSummary"])
        waitFor(app.descendants(matching: .any)["share.status"])
        settle()
        screenshot("02-timeline")

        // 03 · 报告 + AI 解释 — the explained lab report.
        element(containing: reportCardText).tap()
        waitFor(app.navigationBars[details])
        // The explanation card sits below the recording card; bring its
        // top (the attachment chips under the title) into view.
        waitFor(app.descendants(matching: .any)["explain.summary"])
        let chips = app.buttons["explain.attachment.0"]
        scrollTo(chips)
        // A swipe is too coarse here; drag the chips row up to just under
        // the navigation bar so the card's title, chips and summary fill
        // the screen.
        let window = app.windows.firstMatch
        let from = chips.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let to = window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
        from.press(forDuration: 0.1, thenDragTo: to, withVelocity: .slow, thenHoldForDuration: 0.3)
        settle()
        screenshot("03-report-explain")
        backToTimeline()

        // 04 · 面诊录音 — the recording card with play control and waveform.
        element(containing: t("胎心音正常 152 bpm", "Fetal heart rate normal, 152 bpm")).tap()
        waitFor(app.navigationBars[details])
        let card = app.descendants(matching: .any)["recording.card"]
        scrollTo(card)
        settle()
        screenshot("04-visit-recording")

        // 05 · 面诊总结 — said-plainly summary, key points, follow-ups.
        let summaryLine = app.buttons["recording.summaryLine"]
        scrollTo(summaryLine)
        summaryLine.tap()
        waitFor(app.descendants(matching: .any)["summary.said"])
        settle()
        screenshot("05-visit-summary")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        waitFor(app.navigationBars[details])

        // 06 · 我的疑问 — Chinese questions with their English translations.
        // Kept Chinese in the English set too: writing in your own language
        // and handing the doctor English is the feature being shown.
        let questions = app.buttons["recording.questions"]
        scrollTo(questions)
        questions.tap()
        waitFor(app.descendants(matching: .any)["questions.page"])
        settle()
        screenshot("06-questions")
    }

    /// 07 · 订阅页 — Carelogue Plus, with the store's own price. The lab
    /// report in the demo store carries a cached explanation (readable even
    /// unsubscribed), so the shot selects the not-yet-explain ultrasound
    /// first — that is the state where the lock actually appears.
    func testPaywallScreen() {
        // Not pinned to "none": with the status forced, the paywall's own
        // price load never lands on screen. The simulator holds no
        // subscription, so the real StoreKit answer is "not subscribed" and
        // the lock shows all the same — with the store's price on it.
        stickyArguments = []
        launch(["-uitest-reset", "-uitest-seed-demo", "-uitest-icloud-account"])

        openJourney(journeyName)
        element(containing: reportCardText).tap()
        waitFor(app.navigationBars[details])

        // The explanation card's own attachment chips (not the gallery,
        // whose tiles open a preview).
        let ultrasound = app.buttons["explain.attachment.1"]
        waitFor(ultrasound)
        ultrasound.tap()
        let subscribe = app.buttons["explain.subscribe"]
        scrollTo(subscribe)
        subscribe.tap()
        waitFor(app.descendants(matching: .any)["paywall"])
        // The price label reads "价格加载中" until StoreKit answers; never
        // shoot that. Wait for the store's own price to be in it.
        let price = app.descendants(matching: .any)["paywall.price"]
        waitFor(price, timeout: 15)
        let loaded = expectation(for: NSPredicate(format: "label CONTAINS '3.99'"),
                                 evaluatedWith: price)
        wait(for: [loaded], timeout: 30)
        settle()
        screenshot("07-paywall")
    }
}

/// The same seven shots with the app in English, for the en-CA listing.
final class ASCScreenshotEnglishUITests: ASCScreenshotUITests {
    override func setUpWithError() throws {
        try super.setUpWithError()
        language = "en"
    }
}
