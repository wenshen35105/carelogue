import XCTest
import StoreKitTest

/// T27: the paywall, the locked explanation card, and a real StoreKit purchase
/// against the local Carelogue.storekit configuration (referenced from the
/// scheme, so no App Store account is involved).
final class SubscriptionUITests: CarelogueUITestCase {
    private let journeyName = "UITest 孕期"

    /// Local StoreKit environment (CarelogueUITests/Carelogue.storekit): real
    /// StoreKit 2 calls, no App Store account, and purchase dialogs answered
    /// automatically so the flow can run unattended.
    private var storeKit: SKTestSession!

    override func setUpWithError() throws {
        try super.setUpWithError()
        storeKit = try SKTestSession(configurationFileNamed: "Carelogue")
        storeKit.resetToDefaultState()
        storeKit.clearTransactions()
        storeKit.disableDialogs = true
    }

    override func tearDownWithError() throws {
        storeKit?.clearTransactions()
        storeKit = nil
    }

    private func id(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    private func openSeededEncounter() {
        openJourney(journeyName)
        element(containing: "UITest 附件就诊").tap()
        waitFor(app.navigationBars["详情"])
    }

    /// Without a subscription the explanation slot is a guided card — and
    /// nothing else on the page is locked.
    func testLockedCardReplacesExplainEntry() {
        stickyArguments = ["-uitest-subscription", "none"]
        launch(["-uitest-reset", "-uitest-seed-attachments"])
        openSeededEncounter()

        waitFor(id("explain.locked"))
        XCTAssertFalse(app.buttons["explain.button"].exists, "解释 entry should be replaced by the locked card")
        XCTAssertTrue(element(containing: "订阅后解锁报告解读").exists)
        // Records and attachments stay free: the gallery is still usable.
        XCTAssertTrue(app.buttons.matching(identifier: "attachment.image").firstMatch.exists)
        screenshot("T27-report-locked")

        app.buttons["explain.subscribe"].tap()
        waitFor(id("paywall"))
        XCTAssertTrue(element(containing: "Carelogue Plus").exists)
        XCTAssertTrue(app.buttons["paywall.subscribe"].exists)
        XCTAssertTrue(app.buttons["paywall.restore"].exists)
        screenshot("T27-paywall")

        app.buttons["关闭"].tap()
        waitFor(id("explain.locked"))
    }

    /// The paywall shows the price the store reports, not a hard-coded one.
    func testPaywallShowsStorePrice() {
        launch(["-uitest-reset", "-uitest-seed-attachments"])
        openSeededEncounter()
        waitFor(id("explain.locked"), timeout: 10)
        app.buttons["explain.subscribe"].tap()

        let price = id("paywall.price")
        waitFor(price, timeout: 10)
        XCTAssertTrue(price.label.contains("4.99"), "Unexpected price: \(price.label)")
    }

    /// T27 acceptance: an expired subscription degrades to the locked card
    /// instead of crashing, and the explanation already generated stays
    /// readable.
    func testExpiredSubscriptionDegradesGracefully() {
        launch(["-uitest-reset", "-uitest-seed-attachments", "-uitest-fake-ai", "success"])
        openSeededEncounter()

        // Subscribe, explain once.
        waitFor(id("explain.locked"), timeout: 10)
        app.buttons["explain.subscribe"].tap()
        waitFor(id("paywall"))
        app.buttons["paywall.subscribe"].tap()
        tapFirstExisting([app.buttons["好"], app.buttons["OK"]], timeout: 25)
        let explain = app.buttons["explain.button"]
        waitFor(explain, timeout: 20)
        explain.tap()
        let accept = app.buttons["consent.accept"]
        if accept.waitForExistence(timeout: 2) { accept.tap() }
        waitFor(id("explain.summary"), timeout: 20)

        // Expire it behind the app's back, then come back to the report.
        try? storeKit.expireSubscription(productIdentifier: "com.jiajinlinpersonalteam.Carelogue.plus.monthly")
        relaunch()
        openSeededEncounter()

        // The cached explanation is still there (it was already paid for)…
        waitFor(id("explain.summary"), timeout: 20)
        screenshot("T27-expired-keeps-explanation")

        // …and an attachment that was never explained is locked again.
        app.buttons["explain.attachment.2"].tap()
        waitFor(id("explain.locked"), timeout: 10)
    }

    /// Buys through StoreKit Testing and checks the lock actually lifts.
    func testPurchaseUnlocksExplaining() {
        launch(["-uitest-reset", "-uitest-seed-attachments", "-uitest-fake-ai", "success"])
        openSeededEncounter()

        waitFor(id("explain.locked"), timeout: 10)
        app.buttons["explain.subscribe"].tap()
        waitFor(id("paywall"))
        app.buttons["paywall.subscribe"].tap()

        // disableDialogs means the purchase goes straight through; the app
        // then says so and closes the paywall.
        tapFirstExisting([app.buttons["好"], app.buttons["OK"]], timeout: 25)

        // Back on the report: the explain entry is there and works.
        let explain = app.buttons["explain.button"]
        waitFor(explain, timeout: 20)
        screenshot("T27-unlocked")
        explain.tap()
        let accept = app.buttons["consent.accept"]
        if accept.waitForExistence(timeout: 2) { accept.tap() }
        waitFor(id("explain.summary"), timeout: 20)
    }
}
