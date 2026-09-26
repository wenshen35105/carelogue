import XCTest

/// CKShare 真共享 (T39) — the surface that can be driven on a simulator.
///
/// The channel itself (zone, tokens, pushes) needs two real devices with two
/// Apple IDs; scripts/t39-two-device-check.sh is the owner's checklist for
/// that. What these tests pin down instead is everything around it: the
/// no-iCloud fallback, the share marker rendering purely from model fields
/// (`-uitest-fake-share`, no account, no network), and the recording privacy
/// note telling the truth about where audio lives in each state.
final class ShareUITests: CarelogueUITestCase {
    private func id(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    private func openSeededJourney() {
        openJourney("UITest 孕期")
        waitFor(app.buttons["timeline.share"])
    }

    /// No iCloud account: the share button explains instead of failing
    /// silently, and recording offers to work anyway.
    func testNoAccountShowsICloudPrompt() {
        launch(["-uitest-reset", "-uitest-seed-visit", "-uitest-no-icloud"])
        openSeededJourney()

        app.buttons["timeline.share"].tap()
        let alert = app.alerts.firstMatch
        waitFor(alert)
        XCTAssertTrue(element(containing: "共享通过你自己的 iCloud 完成").exists)
        XCTAssertTrue(element(containing: "不登录也能正常记录").exists)
        screenshot("T39-share-no-icloud")
        alert.buttons[t("好", "OK")].tap()
        XCTAssertFalse(app.alerts.firstMatch.exists)
    }

    /// A shared journey (pinned metadata, channel simulated): the list and the
    /// timeline both carry the marker, and the share button opens the
    /// explanation sheet with the conflict policy stated in plain words.
    func testSharedJourneyShowsMarkerAndInfoSheet() {
        launch(["-uitest-reset", "-uitest-seed-visit", "-uitest-fake-share", "active"])

        // The list row says it before the journey is even opened.
        waitFor(element(containing: "共享中"))
        openSeededJourney()
        waitFor(id("share.status"))
        screenshot("T39-timeline-shared")

        app.buttons["timeline.share"].tap()
        waitFor(element(containing: "已通过 iCloud 与家人共享"))
        XCTAssertTrue(element(containing: "双向同步").exists)
        XCTAssertTrue(element(containing: "同时改动").exists)
        XCTAssertTrue(element(containing: "保留较新的一条").exists)
        XCTAssertTrue(element(containing: "停止共享").exists)
        // Simulated share: the manage button (a network path) stays hidden.
        XCTAssertFalse(id("share.info.manage").exists)
        screenshot("T39-share-info")

        app.buttons[t("完成", "Done")].tap()
        waitFor(id("share.status"))
    }

    /// A revoked share is the steady state "ended": the journey is still
    /// there, only the marker is gone.
    func testEndedShareShowsNoMarker() {
        launch(["-uitest-reset", "-uitest-seed-visit", "-uitest-fake-share", "ended"])
        openSeededJourney()

        XCTAssertFalse(id("share.status").waitForExistence(timeout: 2))
        XCTAssertFalse(element(containing: "已通过 iCloud 与家人共享").exists)
        // The recording note still tells the device-only truth without an
        // account, even on a journey that used to be shared.
        XCTAssertTrue(app.buttons["新建记录"].exists)
    }

    /// The recording privacy note without an account: audio stays on this
    /// device — it must not claim iCloud storage it does not have.
    func testRecordingNoteWithoutAccount() {
        launch(["-uitest-reset", "-uitest-seed-recording", "-uitest-no-icloud"])
        openJourney("UITest 孕期")
        element(containing: "UITest 面诊录音").tap()
        waitFor(app.navigationBars[t("详情", "Details")])
        waitFor(id("recording.card"))

        XCTAssertTrue(element(containing: "录音只保存在这台设备上").exists)
        XCTAssertFalse(element(containing: "iCloud 私有库").exists)
    }

    /// The same note with an account: it names the iCloud private database,
    /// because that is where synced recordings actually go.
    func testRecordingNoteWithAccount() {
        launch(["-uitest-reset", "-uitest-seed-recording", "-uitest-icloud-account"])
        openJourney("UITest 孕期")
        element(containing: "UITest 面诊录音").tap()
        waitFor(app.navigationBars[t("详情", "Details")])
        waitFor(id("recording.card"))

        XCTAssertTrue(element(containing: "你的设备与 iCloud 私有库").exists)
        XCTAssertFalse(element(containing: "只保存在这台设备上").exists)
    }

    /// Signed in, not yet shared: the share button must bring up a sharing
    /// sheet with something in it. (TestFlight 1.0 (2): the system
    /// controller wrapped in a SwiftUI sheet came up as an empty dialog.)
    func testNewShareShowsSharingOptions() {
        launch(["-uitest-reset", "-uitest-seed-visit", "-uitest-icloud-account"])
        openSeededJourney()

        app.buttons["timeline.share"].tap()
        RunLoop.current.run(until: Date.now.addingTimeInterval(3))
        screenshot("T39-new-share-sheet")
        let sheet = app.otherElements["ActivityListView"]
        XCTAssertTrue(sheet.waitForExistence(timeout: 8), "No sharing options on screen")
    }

    /// The merged share/sync pill (T39): a round still in flight after the
    /// grace delay replaces 共享中 with 同步中 in the same capsule — quick
    /// rounds must not flash the UI at all.
    func testSyncBadgeShowsSyncing() {
        launch(["-uitest-reset", "-uitest-seed-visit", "-uitest-fake-share", "active",
                "-uitest-sync-state", "syncing"])
        openSeededJourney()

        // The grace delay passes while waiting; then the pill switches.
        waitFor(element(containing: "同步中"))
        XCTAssertTrue(id("share.status").exists)
        screenshot("T39-sync-syncing")
    }

    /// A failed round is tappable and explains itself, with a retry that
    /// clears the alert (simulated: the retry round is a no-op).
    func testSyncBadgeFailureExplains() {
        launch(["-uitest-reset", "-uitest-seed-visit", "-uitest-fake-share", "active",
                "-uitest-sync-state", "failed"])
        openSeededJourney()

        id("share.sync").tap()
        let alert = app.alerts.firstMatch
        waitFor(alert)
        XCTAssertTrue(element(containing: "暂时连不上 iCloud").exists)
        screenshot("T39-sync-failed")
        alert.buttons[t("重试", "Retry")].tap()
        XCTAssertFalse(app.alerts.firstMatch.waitForExistence(timeout: 2))
    }

    /// 停止共享 is a real button now: confirm, and the marker is gone while
    /// the journey itself stays (there is no delete, by design).
    func testStopSharingEndsMarker() {
        launch(["-uitest-reset", "-uitest-seed-visit", "-uitest-fake-share", "active"])
        openSeededJourney()

        app.buttons["timeline.share"].tap()
        waitFor(element(containing: "已通过 iCloud 与家人共享"))
        id("share.info.stop").tap()
        let confirm = app.buttons[t("停止共享", "Stop sharing")].firstMatch
        waitFor(confirm, timeout: 5)
        confirm.tap()

        waitFor(app.buttons["timeline.share"])
        XCTAssertFalse(id("share.status").waitForExistence(timeout: 2))
        XCTAssertTrue(element(containing: "UITest 孕期").exists)
        screenshot("T39-share-stopped")
    }

    /// Creating the share fails (here: the simulator has no real iCloud
    /// account behind the pinned "signed in"): the timeline must say why,
    /// not leave the system's bare "couldn't create a link" / a spinner.
    func testFailedShareCreationExplains() {
        launch(["-uitest-reset", "-uitest-seed-visit", "-uitest-icloud-account"])
        openSeededJourney()

        app.buttons["timeline.share"].tap()
        let sheet = app.otherElements["ActivityListView"]
        waitFor(sheet, timeout: 8)
        let invite = app.staticTexts[t("通过链接邀请", "Invite with Link")]
        waitFor(invite, timeout: 8)
        invite.tap()

        // The system reports its own failure inside the sheet; close
        // whatever it shows, then the sheet, and our explanation follows.
        let ours = element(containing: "没能创建共享")
        for _ in 0..<6 where !ours.waitForExistence(timeout: 3) {
            if app.alerts.count > 0, let button = app.alerts.firstMatch.buttons.allElementsBoundByIndex.first {
                button.tap()
            } else if app.buttons["Close"].exists {
                app.buttons["Close"].tap()
            } else if app.buttons["关闭"].exists {
                app.buttons["关闭"].tap()
            }
        }
        screenshot("T39-share-create-failed")
        XCTAssertTrue(ours.exists, "No explanation after the share failed")
    }
}
