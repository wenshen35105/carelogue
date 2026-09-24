import XCTest

/// Shared helpers for Carelogue UI tests. Launch flags are handled by
/// `UITestSupport` in the app (Debug builds only).
@MainActor
class CarelogueUITestCase: XCTestCase {
    var app: XCUIApplication!

    // Synchronous on purpose: continueAfterFailure = false stops a test by
    // raising an exception, which cannot unwind through async frames and
    // crashed the runner (xcodebuild then hung).
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    /// App language for this test. Queries in the suite use the Chinese UI
    /// labels, so tests pin zh-Hans unless they opt into English.
    var language = "zh-Hans"

    /// Flags every launch in this test keeps, including relaunches — e.g. the
    /// pinned subscription state, which is not data and must survive the kill.
    var stickyArguments: [String] = []

    func launch(_ arguments: [String] = []) {
        let locale = language.hasPrefix("zh") ? "zh_CN" : "en_CA"
        app.launchArguments = ["-AppleLanguages", "(\(language))", "-AppleLocale", locale]
            + stickyArguments + arguments
        app.launch()
    }

    /// Kill and relaunch without data flags, so data must come from the store.
    func relaunch() {
        app.terminate()
        launch()
    }

    // MARK: - Queries

    func element(containing text: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", text))
            .firstMatch
    }

    func button(containing text: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    /// Scrolls the page down until `element` is on screen and tappable.
    ///
    /// SwiftUI stops vending accessibility for content far below the fold, so
    /// an element that exists in the view tree can be invisible to a query
    /// until it is scrolled near. Pages grow (the visit detail gained the
    /// recording card in T32), so tests scroll rather than assume a position.
    @discardableResult
    func scrollTo(_ element: XCUIElement, maxSwipes: Int = 6, timeout: TimeInterval = 3,
                  file: StaticString = #filePath, line: UInt = #line) -> Bool {
        for _ in 0..<maxSwipes {
            if isComfortablyVisible(element) { return true }
            app.swipeUp()
        }
        // Swiping is coarse, so a short page can be scrolled straight past
        // the target; walk back up before giving up.
        for _ in 0..<maxSwipes {
            if isComfortablyVisible(element) { return true }
            app.swipeDown()
        }
        let found = element.waitForExistence(timeout: timeout) && element.isHittable
        XCTAssertTrue(found, "Never scrolled to: \(element)", file: file, line: line)
        return found
    }

    /// Not just on screen: clear of the edges. A row sitting half under the
    /// home indicator reports as hittable, and tapping it does nothing.
    private func isComfortablyVisible(_ element: XCUIElement, margin: CGFloat = 60) -> Bool {
        guard element.exists, element.isHittable else { return false }
        let window = app.windows.firstMatch.frame
        let frame = element.frame
        // An element taller than the window can never clear both edges.
        guard frame.height < window.height - 2 * margin else { return true }
        return frame.minY >= window.minY + margin && frame.maxY <= window.maxY - margin
    }

    func waitFor(_ element: XCUIElement, timeout: TimeInterval = 5, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "Missing element: \(element)", file: file, line: line)
    }

    func waitForCount(_ query: XCUIElementQuery, _ expected: Int, timeout: TimeInterval = 5,
                      file: StaticString = #filePath, line: UInt = #line) {
        let deadline = Date.now.addingTimeInterval(timeout)
        while query.count != expected && Date.now < deadline {
            RunLoop.current.run(until: Date.now.addingTimeInterval(0.2))
        }
        XCTAssertEqual(query.count, expected, file: file, line: line)
    }

    func tapFirstExisting(_ candidates: [XCUIElement], timeout: TimeInterval = 5,
                          file: StaticString = #filePath, line: UInt = #line) {
        let deadline = Date.now.addingTimeInterval(timeout)
        while Date.now < deadline {
            if let hit = candidates.first(where: { $0.exists && $0.isHittable }) {
                hit.tap()
                return
            }
            RunLoop.current.run(until: Date.now.addingTimeInterval(0.2))
        }
        XCTFail("None of the candidates appeared: \(candidates)", file: file, line: line)
    }

    // MARK: - Common flows

    /// Picks the label for the language this test runs in. Seeded data keeps
    /// its own wording; only the UI's own strings change.
    func t(_ zh: String, _ en: String) -> String {
        language.hasPrefix("zh") ? zh : en
    }

    func openJourney(_ name: String) {
        let row = app.staticTexts[name]
        waitFor(row)
        row.tap()
        waitFor(app.buttons[t("新建记录", "New Entry")])
    }

    /// Timeline FAB -> Menu item (就诊 / 随手记 / 测量).
    func startNewLog(_ kind: String) {
        app.buttons["新建记录"].tap()
        let item = app.buttons[kind]
        waitFor(item)
        item.tap()
        waitFor(app.navigationBars["新建记录"])
    }

    /// Taps a ChipButton until it reports the selected trait (taps that land
    /// while a sheet is still animating in are otherwise silently dropped).
    func selectChip(_ label: String, file: StaticString = #filePath, line: UInt = #line) {
        let chip = app.buttons[label]
        waitFor(chip, file: file, line: line)
        for _ in 0..<5 where !chip.isSelected {
            chip.tap()
            _ = chip.waitForSelected(timeout: 1)
        }
        XCTAssertTrue(chip.isSelected, "Chip \(label) did not become selected", file: file, line: line)
    }

    /// Taps 删除 in the confirmation dialog. Queries the action sheet first:
    /// timeline rows also carry hidden swipe-action buttons named 删除.
    func confirmDelete() {
        tapFirstExisting([app.sheets.buttons["删除"], app.scrollViews.buttons["删除"], app.buttons["删除"]])
    }

    // MARK: - Screenshots

    /// Attaches a screenshot to the test result and, when the runner has
    /// SCREENSHOT_DIR set (scripts/ui-test.sh passes it), writes a PNG there.
    func screenshot(_ name: String) {
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        if let dir = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"], !dir.isEmpty {
            let url = URL(fileURLWithPath: dir).appendingPathComponent("\(name).png")
            try? shot.pngRepresentation.write(to: url)
        }
    }
}

extension XCUIElement {
    func waitForSelected(timeout: TimeInterval) -> Bool {
        let deadline = Date.now.addingTimeInterval(timeout)
        while !isSelected && Date.now < deadline {
            RunLoop.current.run(until: Date.now.addingTimeInterval(0.1))
        }
        return isSelected
    }
}
