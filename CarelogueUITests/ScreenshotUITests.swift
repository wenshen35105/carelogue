import XCTest

/// Documentation screenshots for docs/screenshots (M1 T3–T9, plus the M2
/// cards T10–T14 re-shot on the same data). Everything runs on the
/// `-uitest-seed-demo` store, so the shots show a Journey in full swing
/// instead of a one-record test fixture.
///
///   scripts/ui-test.sh -only-testing:CarelogueUITests/ScreenshotUITests
///   APPEARANCE=dark scripts/ui-test.sh \
///     -only-testing:CarelogueUITests/ScreenshotUITests/testDarkModeScreens
final class ScreenshotUITests: CarelogueUITestCase {
    private let journeyName = "孕期档案"
    private let reportCardText = "就诊 · 验血"

    // The seeded report already carries a cached explanation; a pinned
    // subscription keeps the detail page in its normal (unlocked) layout.
    override func setUpWithError() throws {
        try super.setUpWithError()
        stickyArguments = ["-uitest-subscription", "active"]
    }

    private func launchDemo() {
        launch(["-uitest-reset", "-uitest-seed-demo"])
        waitFor(app.navigationBars["Journeys"])
    }

    /// Screenshots settle better one runloop after the view appears: the
    /// card shadows and chip animations are still cross-fading otherwise.
    private func settle(_ seconds: TimeInterval = 0.8) {
        RunLoop.current.run(until: Date.now.addingTimeInterval(seconds))
    }

    /// Ends editing before an editor shot: the keyboard otherwise hides the
    /// lower half of the form (attachments, 时间, 数值).
    private func dismissKeyboard() {
        // Tapping the 类型 section header ends editing; when the form has
        // scrolled that header out of reach, scroll back up and retry.
        for _ in 0..<4 where app.keyboards.element.exists {
            let header = app.staticTexts["类型"].firstMatch
            if header.exists, header.isHittable {
                header.tap()
            } else {
                app.swipeDown()
            }
            settle(0.4)
        }
    }

    private func backToJourneys() {
        tapFirstExisting([app.navigationBars.buttons["Journeys"],
                          app.navigationBars.buttons.element(boundBy: 0)])
        waitFor(app.navigationBars["Journeys"])
    }

    // MARK: - T3 / T4 / T8 / T9

    func testListTimelineProfileScreens() {
        launchDemo()

        // T3 · P1 Journey 列表: one running Journey + one archived.
        waitFor(app.staticTexts[journeyName])
        waitFor(app.staticTexts["拔智齿记录"])
        settle()
        screenshot("T3-journeys")

        // T4 · P2 时间线: upcoming appointment, encounters, quick note,
        // the AI summary line and the collapsed measurement group.
        openJourney(journeyName)
        waitFor(element(containing: "下次"))
        waitFor(app.descendants(matching: .any)["timeline.aiSummary"])
        settle()
        screenshot("T4-timeline")
        backToJourneys()

        // T8 · P4 档案（已填）.
        button(containing: "档案与设置").tap()
        waitFor(app.navigationBars["档案 · Profile"])
        settle()
        screenshot("T8-profile")
        app.buttons["完成"].tap()
        waitFor(app.navigationBars["Journeys"])

        // T3 · 新建旅程 sheet（模板步骤）.
        button(containing: "新建健康旅程").tap()
        let nameField = app.textFields.firstMatch
        waitFor(nameField)
        nameField.typeText("年度体检")
        app.buttons["下一步"].tap()
        let template = app.buttons["自定义"]
        waitFor(template)
        settle(0.5)
        screenshot("T3-journey-create")

        // T9 · 新旅程的空时间线（M1 验收走查的起点）.
        template.tap()
        openJourney("年度体检")
        waitFor(element(containing: "还没有记录"))
        settle(0.5)
        screenshot("T9-timeline-empty")
    }

    // MARK: - T5 / T6

    func testEditorScreens() {
        launchDemo()
        openJourney(journeyName)

        // T5 · 就诊编辑器.
        startNewLog("就诊")
        selectChip("面诊")
        // The note goes in first: dismissKeyboard() can end editing in a
        // TextField, but not in the note's TextEditor.
        let note = app.textViews.firstMatch
        waitFor(note)
        note.tap()
        note.typeText("常规产检：血压 112/70，宫高 26cm。下次预约两周后。")
        let location = app.textFields["地点"]
        location.tap()
        location.typeText("BC Women's Hospital")
        let doctor = app.textFields["医生"]
        doctor.tap()
        // Return on the last TextField ends editing, so the attachment
        // section isn't hidden behind the keyboard in the shot.
        doctor.typeText("Dr. Chen\n")
        dismissKeyboard()
        settle(0.5)
        screenshot("T5-editor-encounter")
        app.buttons["取消"].tap()

        // T6 · 随手记编辑器（备注体，自动聚焦）.
        startNewLog("随手记")
        let noteField = app.textViews.firstMatch
        waitFor(noteField)
        noteField.typeText("今天散步 30 分钟，胎动比昨天明显。")
        dismissKeyboard()
        settle(0.5)
        screenshot("T6-editor-quick")
        app.buttons["取消"].tap()

        // T6 · 测量编辑器（类型 + 数值 + 单位）.
        startNewLog("测量")
        let value = app.textFields["数值"]
        waitFor(value)
        value.tap()
        value.typeText("64.8")
        dismissKeyboard()
        settle(0.5)
        screenshot("T6-editor-measurement")
        app.buttons["取消"].tap()
        waitFor(app.buttons["新建记录"])
    }

    // MARK: - T7 / T10 / T11

    func testDetailAttachmentScreens() {
        launchDemo()
        openJourney(journeyName)

        // T7 · 详情页（就诊 · 面诊：地点/医生 + 备注）.
        element(containing: "就诊 · 面诊").tap()
        waitFor(app.navigationBars["详情"])
        settle()
        screenshot("T7-detail")

        // T7 · 删除确认.
        app.buttons["删除记录"].tap()
        waitFor(app.buttons["取消"])
        settle(0.5)
        screenshot("T7-delete-confirm")
        tapFirstExisting([app.sheets.buttons["取消"], app.buttons["取消"]])
        tapFirstExisting([app.navigationBars.buttons[journeyName],
                          app.navigationBars.buttons.element(boundBy: 0)])

        // T11 · 详情页的附件宫格（验血：2 图 + 1 PDF）. The explanation card
        // sits above it, so the page is scrolled down to the gallery — the
        // explained card itself is documented by the T20 shots.
        element(containing: reportCardText).tap()
        waitFor(app.navigationBars["详情"])
        waitFor(app.descendants(matching: .any)["explain.summary"])
        let gallery = app.buttons.matching(identifier: "attachment.image").firstMatch
        for _ in 0..<6 where !gallery.isHittable {
            app.swipeUp()
        }
        waitFor(gallery)
        settle()
        screenshot("T11-detail-attachments")

        // T11 · PDF 预览.
        app.buttons.matching(identifier: "attachment.file").firstMatch.tap()
        waitFor(app.descendants(matching: .any)["attachment.preview"])
        settle()
        screenshot("T11-pdf-preview")
        app.buttons["关闭"].tap()
        waitFor(app.navigationBars["详情"])

        // T10 · 编辑器里的附件列表.
        app.buttons["编辑"].tap()
        waitFor(app.navigationBars["编辑记录"])
        waitFor(app.descendants(matching: .any).matching(identifier: "editor.attachment").firstMatch)
        app.swipeUp()
        settle()
        screenshot("T10-editor-attachments")
        app.buttons["取消"].tap()
        waitFor(app.navigationBars["详情"])
    }

    // MARK: - T12 / T13

    func testMeasurementScreens() {
        launchDemo()
        openJourney(journeyName)

        // T12 · 展开测量组 + 筛选 chips.
        app.buttons["measurement.group"].tap()
        waitFor(app.buttons["全部 16"])
        selectChip("血压 3")
        waitForCount(app.buttons.matching(identifier: "measurement.row"), 3)
        settle()
        screenshot("T12-measurement-filter")

        // T13 · 体重趋势图表.
        selectChip("体重 12")
        app.buttons["查看图表"].tap()
        waitFor(app.navigationBars["趋势 · Trends"])
        waitFor(element(containing: "12 次记录"))
        settle()
        screenshot("T13-chart-weight")
        app.buttons["完成"].tap()
    }

    // MARK: - T14（深色模式，需 APPEARANCE=dark）

    func testDarkModeScreens() {
        launchDemo()

        openJourney(journeyName)
        waitFor(app.descendants(matching: .any)["timeline.aiSummary"])
        settle()
        screenshot("T14-timeline-dark")

        element(containing: reportCardText).tap()
        waitFor(app.navigationBars["详情"])
        waitFor(app.descendants(matching: .any)["explain.summary"])
        settle()
        screenshot("T14-detail-dark")
    }
}
