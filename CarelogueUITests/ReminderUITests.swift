import XCTest

/// M8 T52 (visit reminders) and T53 (medication reminders): reminders are
/// planned from the store and follow every edit; the notifications really
/// arrive; medication doses can be checked in from the list and from the
/// notification itself.
final class ReminderUITests: CarelogueUITestCase {
    // MARK: - T52 visits

    func testVisitReminderFollowsTheVisit() {
        launch(["-uitest-reset", "-uitest-seed-upcoming"])
        openJourney("UITest 复诊")

        // No reminder yet: no pill on the upcoming card.
        let upcoming = element(containing: "下次 · 面诊")
        waitFor(upcoming)
        XCTAssertFalse(element(containing: "已设提醒").exists)

        // Upcoming card -> detail -> 编辑 -> 提醒我 on (defaults fill in).
        upcoming.tap()
        waitFor(app.navigationBars["详情"])
        app.buttons["编辑"].tap()
        waitFor(app.navigationBars["编辑记录"])
        let toggle = app.switches["editor.reminderToggle"]
        scrollTo(toggle)
        flip(toggle)
        allowNotificationsIfAsked()
        waitFor(element(containing: "前一天"))
        waitFor(element(containing: "当天"))
        XCTAssertEqual(app.buttons.matching(identifier: "reminder.day").count, 2)
        screenshot("T52-visit-editor")
        app.buttons["保存"].tap()

        // Back on the timeline the card says a reminder is set.
        waitFor(app.navigationBars["详情"])
        app.navigationBars.buttons.element(boundBy: 0).tap()
        waitFor(element(containing: "已设提醒"))
        screenshot("T52-timeline-reminder-set")

        // Both times are planned.
        app.navigationBars.buttons.element(boundBy: 0).tap()
        openSettingsPage()
        waitForPlanned("visits 2")
        screenshot("T52-settings-reminders")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["完成"].tap()

        // Persisted: relaunch, still planned.
        relaunch()
        openSettingsPage()
        waitForPlanned("visits 2")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["完成"].tap()

        // Delete the visit -> its reminders go with it.
        openJourney("UITest 复诊")
        element(containing: "下次 · 面诊").tap()
        waitFor(app.navigationBars["详情"])
        app.buttons["删除记录"].tap()
        confirmDelete()
        XCTAssertTrue(element(containing: "下次 · 面诊").waitForNonExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        openSettingsPage()
        waitForPlanned("visits 0")
    }

    func testVisitReminderTurnsOffAndEditsDefaults() {
        launch(["-uitest-reset", "-uitest-seed-reminder-soon"])
        openSettingsPage()
        waitForPlanned("visits 1")

        // Settings: add a default time (shown on the card).
        let add = app.buttons["settings.addReminderDefault"]
        scrollTo(add)
        add.tap()
        waitForCount(app.buttons.matching(identifier: "reminder.day"), 3)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["完成"].tap()

        // Turning the visit's reminder off cancels it.
        openJourney("UITest 复诊")
        element(containing: "下次 · 面诊").tap()
        waitFor(app.navigationBars["详情"])
        app.buttons["编辑"].tap()
        let toggle = app.switches["editor.reminderToggle"]
        scrollTo(toggle)
        XCTAssertEqual(toggle.value as? String, "1")
        flip(toggle)
        app.buttons["保存"].tap()
        waitFor(app.navigationBars["详情"])
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(element(containing: "已设提醒").waitForNonExistence(timeout: 3))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        openSettingsPage()
        waitForPlanned("visits 0")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["完成"].tap()

        // Switching it back on starts from the new defaults (three times).
        openJourney("UITest 复诊")
        element(containing: "下次 · 面诊").tap()
        app.buttons["编辑"].tap()
        scrollTo(toggle)
        flip(toggle)
        waitForCount(app.buttons.matching(identifier: "reminder.day"), 3)
    }

    /// The real thing: a reminder set for the next minute shows up as a
    /// banner with the visit's name, time and place.
    func testVisitReminderArrives() {
        launch(["-uitest-reset", "-uitest-seed-reminder-soon", "-uitest-request-notifications"])
        allowNotificationsIfAsked()
        waitFor(app.navigationBars["Journeys"])
        let banner = springboard.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "就诊提醒")).firstMatch
        XCTAssertTrue(banner.waitForExistence(timeout: 140), "No visit reminder banner")
        XCTAssertTrue(banner.label.contains("Women's Health Clinic"), "Banner lacks the place: \(banner.label)")
        screenshot("T52-banner")
    }

    // MARK: - T53 medications

    func testMedicationPlanAndCheckIn() {
        launch(["-uitest-reset"])
        waitFor(app.navigationBars["Journeys"])
        let entry = app.buttons["home.medications"]
        scrollTo(entry)
        XCTAssertTrue(entry.label.contains("添加用药计划"), entry.label)
        entry.tap()

        // Empty list -> 添加用药.
        let addFirst = app.buttons["medications.addFirst"]
        waitFor(addFirst)
        screenshot("T53-empty")
        addFirst.tap()
        waitFor(app.navigationBars["添加用药"])
        let name = app.textFields["medication.name"]
        name.tap()
        name.typeText("叶酸片")
        let dose = app.textFields["medication.dose"]
        dose.tap()
        dose.typeText("5 mg\n") // return closes the keyboard
        // 08:00 is there by default; add the evening one.
        app.buttons["medication.addTime"].tap()
        waitForCount(app.datePickers.matching(identifier: "medication.time"), 2)
        screenshot("T53-editor")
        app.buttons["medication.save"].tap()
        allowNotificationsIfAsked()

        // The card: 每天 2 次, two dose chips, 打卡.
        waitFor(element(containing: "叶酸片"))
        waitFor(element(containing: "每天 2 次"))
        XCTAssertEqual(app.buttons.matching(identifier: "medication.dose").count, 2)
        let progress = app.otherElements["medications.progress"]
        waitFor(element(containing: "0/2"))

        // 打卡 marks the first open dose; twice finishes the day.
        app.buttons["medication.take"].tap()
        waitFor(element(containing: "1/2"))
        app.buttons["medication.take"].tap()
        waitFor(element(containing: "2/2"))
        waitFor(app.staticTexts["已完成"].firstMatch)
        _ = progress
        screenshot("T53-list-done")

        // Back home: the entry card carries today's progress.
        app.navigationBars.buttons.element(boundBy: 0).tap()
        waitFor(element(containing: "今日已完成 2/2 次"))

        // Persisted across a relaunch.
        relaunch()
        let entryAgain = app.buttons["home.medications"]
        scrollTo(entryAgain)
        XCTAssertTrue(entryAgain.label.contains("2/2"), entryAgain.label)
        entryAgain.tap()

        // Pause: moves to 已暂停, and no doses are planned any more.
        app.buttons["medication.more"].firstMatch.tap()
        app.buttons["暂停提醒"].tap()
        waitFor(element(containing: "已暂停"))
        waitFor(element(containing: "提醒已暂停"))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        openSettingsPage()
        waitForPlanned("doses 0")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["完成"].tap()

        // Resume -> doses planned again (tomorrow's two at least).
        app.buttons["home.medications"].tap()
        app.buttons["medication.more"].firstMatch.tap()
        app.buttons["恢复提醒"].tap()
        waitFor(app.buttons["medication.take"].exists ? app.buttons["medication.take"] : element(containing: "已完成"))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        openSettingsPage()
        let planned = plannedReminders()
        XCTAssertFalse(planned.contains("doses 0"), planned)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["完成"].tap()

        // Delete from the editor.
        app.buttons["home.medications"].tap()
        app.buttons["medication.more"].firstMatch.tap()
        app.buttons["编辑"].tap()
        waitFor(app.navigationBars["编辑用药"])
        let delete = app.buttons["删除用药"]
        scrollTo(delete)
        delete.tap()
        confirmDelete()
        waitFor(app.buttons["medications.addFirst"])
    }

    /// A dose reminder arrives and 已服用 on the notification checks it in.
    func testMedicationReminderActionChecksIn() {
        launch(["-uitest-reset", "-uitest-seed-medication-soon", "-uitest-request-notifications"])
        allowNotificationsIfAsked()
        waitFor(app.navigationBars["Journeys"])
        let banner = springboard.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "服药提醒")).firstMatch
        XCTAssertTrue(banner.waitForExistence(timeout: 140), "No medication reminder banner")
        screenshot("T53-banner")

        // Long-press opens the expanded notification with its actions.
        banner.press(forDuration: 1.2)
        let taken = springboard.buttons["已服用"]
        XCTAssertTrue(taken.waitForExistence(timeout: 5), "No 已服用 action")
        screenshot("T53-banner-actions")
        taken.tap()

        app.activate()
        let entry = app.buttons["home.medications"]
        scrollTo(entry)
        let done = NSPredicate(format: "label CONTAINS %@", "1/1")
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: done, object: entry)], timeout: 8),
                       .completed, entry.label)
    }
}
