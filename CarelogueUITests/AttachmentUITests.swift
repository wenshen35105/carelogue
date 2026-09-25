import XCTest

/// M2 T10 (import) and T11 (gallery / preview / delete).
final class AttachmentUITests: CarelogueUITestCase {
    private let journeyName = "UITest 孕期"

    // These tests are about attachments, not the paywall; a pinned
    // subscription keeps the report page in its normal layout.
    override func setUpWithError() throws {
        try super.setUpWithError()
        stickyArguments = ["-uitest-subscription", "active"]
    }

    private var images: XCUIElementQuery { app.buttons.matching(identifier: "attachment.image") }
    private var files: XCUIElementQuery { app.buttons.matching(identifier: "attachment.file") }

    /// Opens the seeded visit and scrolls to the attachment gallery, which
    /// sits below the recording card (T32).
    private func openSeededEncounter() {
        openJourney(journeyName)
        element(containing: "UITest 附件就诊").tap()
        waitFor(app.navigationBars["详情"])
        scrollTo(images.firstMatch)
    }

    func testPreviewAndDelete() {
        launch(["-uitest-reset", "-uitest-seed-attachments"])
        openSeededEncounter()
        waitForCount(images, 2)
        waitForCount(files, 1)
        screenshot("T11-detail-attachments")

        // Image preview: pinch + double-tap zoom, then close.
        images.firstMatch.tap()
        let preview = app.descendants(matching: .any)["attachment.preview"]
        waitFor(preview)
        preview.pinch(withScale: 2.5, velocity: 2)
        preview.doubleTap()
        screenshot("T11-image-preview")
        app.buttons["关闭"].tap()

        // PDF preview.
        files.firstMatch.tap()
        waitFor(preview)
        screenshot("T11-pdf-preview")

        // Delete from the viewer's trash button.
        app.buttons["删除附件"].tap()
        confirmDelete()
        waitForCount(files, 0)

        // Delete an image via long-press menu.
        images.firstMatch.press(forDuration: 1.2)
        let menuItem = app.buttons["删除附件"]
        waitFor(menuItem)
        menuItem.tap()
        confirmDelete()
        waitForCount(images, 1)

        // Deletions persist across a relaunch.
        relaunch()
        openSeededEncounter()
        waitForCount(images, 1)
        XCTAssertEqual(files.count, 0)
    }

    /// m2-bugs #3 / T25 ④: a PDF over the 20 MB cap is refused with a clear
    /// message and nothing is added. scripts/ui-test.sh generates the
    /// oversized file next to the other fixtures.
    func testOversizePDFIsRejected() {
        launch(["-uitest-reset", "-uitest-seed-measurements"])
        openJourney(journeyName)
        startNewLog("就诊")
        selectChip("面诊")

        let editorRows = app.descendants(matching: .any).matching(identifier: "editor.attachment")
        let filesButton = app.buttons["从文件添加（PDF / 图片）"]
        filesButton.swipeUp()
        waitFor(filesButton)
        filesButton.tap()

        let oversize = app.cells["report_oversize, pdf"]
        revealInDocumentPicker(oversize)
        let settled = expectation(for: NSPredicate(format: "isHittable == true"), evaluatedWith: oversize)
        wait(for: [settled], timeout: 10)
        sleep(1)
        oversize.tap()
        tapFirstExisting([app.buttons["Open"], app.buttons["打开"]])

        let alert = app.alerts["附件导入失败"]
        waitFor(alert, timeout: 15)
        XCTAssertTrue(alert.staticTexts.element(matching: NSPredicate(format: "label CONTAINS %@", "20 MB")).exists,
                      "Size limit not explained: \(alert.staticTexts.allElementsBoundByIndex.map(\.label))")
        screenshot("T25-attachment-too-large")
        alert.buttons["好"].tap()
        XCTAssertEqual(editorRows.count, 0)
    }

    /// Full import through the system pickers. Needs photos in the library and
    /// PDFs under Files > On My iPhone (scripts/ui-test.sh provisions both).
    func testImportFromPhotosAndFiles() throws {
        launch(["-uitest-reset", "-uitest-seed-measurements"])
        openJourney(journeyName)
        startNewLog("就诊")
        selectChip("面诊")

        let editorRows = app.descendants(matching: .any).matching(identifier: "editor.attachment")

        // Photos: pick two.
        let photosButton = app.buttons["从相册添加"]
        photosButton.swipeUp() // bring the attachment section on screen
        waitFor(photosButton)
        photosButton.tap()
        let photos = app.scrollViews.otherElements.images
        XCTAssertTrue(photos.firstMatch.waitForExistence(timeout: 10), "Photo picker shows no photos")
        guard photos.count >= 2 else {
            throw XCTSkip("Photo library has fewer than 2 photos")
        }
        photos.element(boundBy: 0).tap()
        photos.element(boundBy: 1).tap()
        tapFirstExisting([app.buttons["Add"], app.buttons["添加"], app.navigationBars.buttons["Add"]])
        waitForCount(editorRows, 2, timeout: 15)

        // Files: pick two PDFs from On My iPhone.
        app.buttons["从文件添加（PDF / 图片）"].tap()
        let reportA = app.cells["report_a, pdf"]
        let reportB = app.cells["report_b, pdf"]
        revealInDocumentPicker(reportA)
        let settled = expectation(for: NSPredicate(format: "isHittable == true"), evaluatedWith: reportB)
        wait(for: [settled], timeout: 10)
        sleep(1)
        reportA.tap()
        reportB.tap()
        let open = app.buttons["Open"].exists ? app.buttons["Open"] : app.buttons["打开"]
        let enabled = expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: open)
        wait(for: [enabled], timeout: 5)
        tapFirstExisting([app.buttons["Open"], app.buttons["打开"]])
        waitForCount(editorRows, 4, timeout: 15)
        screenshot("T10-editor-imported")

        app.buttons["保存"].tap()
        waitFor(element(containing: "附件 4 份"))

        // Survives kill + relaunch.
        relaunch()
        openJourney(journeyName)
        element(containing: "就诊 · 面诊").tap()
        waitForCount(images, 2)
        waitForCount(files, 2)
        screenshot("T10-detail-after-relaunch")
    }
}
