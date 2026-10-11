import XCTest

/// M8 T58: the widget's snapshot follows the store, and its carelogue://
/// links land in the right place. (The widget itself reads only that
/// snapshot; its faces are shot through the Debug gallery.)
final class WidgetUITests: CarelogueUITestCase {
    private struct Published {
        let next: String
        let latest: String
        let note: String
    }

    /// Reads Settings' Debug line: "Widget next=<id> latest=<id> note=<id>".
    private func published() -> Published {
        openSettingsPage()
        let label = app.staticTexts["debug.widgetSnapshot"]
        scrollTo(label)
        var fields: [String: String] = [:]
        for part in label.label.split(separator: " ").dropFirst() {
            let pair = part.split(separator: "=", maxSplits: 1).map(String.init)
            if pair.count == 2 { fields[pair[0]] = pair[1] }
        }
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["完成"].tap()
        return Published(next: fields["next"] ?? "", latest: fields["latest"] ?? "", note: fields["note"] ?? "")
    }

    func testSnapshotFollowsTheStore() {
        launch(["-uitest-reset", "-uitest-seed-upcoming"])
        waitFor(app.navigationBars["Journeys"])
        let first = published()
        XCTAssertNotEqual(first.next, "none")
        XCTAssertEqual(first.latest, "none")
        XCTAssertNotEqual(first.note, "none")

        // Visit gone: nothing ahead, nothing behind yet.
        openJourney("UITest 复诊")
        element(containing: "下次 · 面诊").tap()
        waitFor(app.navigationBars["详情"])
        app.buttons["删除记录"].tap()
        confirmDelete()
        XCTAssertTrue(element(containing: "下次 · 面诊").waitForNonExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        sleep(1)
        let empty = published()
        XCTAssertEqual(empty.next, "none")
        XCTAssertEqual(empty.latest, "none")

        // A quick note becomes the latest entry.
        openJourney("UITest 复诊")
        startNewLog("随手记")
        app.textViews.firstMatch.typeText("小组件测试")
        app.buttons["保存"].tap()
        waitFor(app.staticTexts["小组件测试"])
        app.navigationBars.buttons.element(boundBy: 0).tap()
        sleep(1)
        XCTAssertNotEqual(published().latest, "none")
    }

    /// Through the system, as a widget tap is: the running app gets the URL.
    /// (XCUIApplication.open would relaunch it with its launch arguments —
    /// a fresh seed with new ids.)
    func testLinksOpenTheVisitAndAQuickNote() {
        launch(["-uitest-reset", "-uitest-seed-upcoming"])
        waitFor(app.navigationBars["Journeys"])
        let ids = published()

        // Tapping the widget's visit opens that visit.
        XCUIDevice.shared.system.open(URL(string: "carelogue://log/\(ids.next)")!)
        waitFor(app.navigationBars["详情"])
        waitFor(element(containing: "Women's Health Clinic"))
        screenshot("T58-link-visit")

        // 记一笔 opens a quick note in the most recent journey.
        XCUIDevice.shared.system.open(URL(string: "carelogue://quick-note/\(ids.note)")!)
        waitFor(app.navigationBars["新建记录"])
        app.textViews.firstMatch.typeText("从小组件记的一笔")
        app.buttons["保存"].tap()
        waitFor(app.staticTexts["从小组件记的一笔"])
        XCTAssertTrue(app.navigationBars["UITest 复诊"].exists)
    }

    func testGalleryScreens() {
        launch(["-uitest-reset", "-uitest-seed-demo", "-uitest-widget-gallery"])
        let medium = app.descendants(matching: .any)["widget.medium"]
        waitFor(medium)
        XCTAssertTrue(medium.label.contains("下次就诊"), medium.label)
        waitFor(element(containing: "记一笔"))
        screenshot("T58-widget-gallery")

        // No data: the invitation.
        app.terminate()
        launch(["-uitest-reset", "-uitest-widget-gallery"])
        let small = app.descendants(matching: .any)["widget.small"]
        waitFor(small)
        XCTAssertTrue(small.label.contains("记录今天"), small.label)
        screenshot("T58-widget-empty")
    }
}
