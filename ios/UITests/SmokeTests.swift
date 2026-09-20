import XCTest
final class SmokeTests: XCTestCase {
    func testThumbFlowIncomeAndFullRefund() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--test-store", UUID().uuidString]
        app.launch()
        app.buttons["new-entry"].tap()
        app.segmentedControls.buttons["收入"].tap()
        XCTAssertTrue(app.buttons["category-二手"].exists)
        XCTAssertTrue(app.buttons["category-工资"].exists)
        XCTAssertFalse(app.buttons["category-食物"].exists)
        app.segmentedControls.buttons["支出"].tap()
        let input = app.textFields["entry-tag"]
        input.tap(); input.typeText("tao")
        XCTAssertEqual(input.value as? String, "tao")
        app.buttons["标签完成"].tap()
        app.buttons["key-1"].tap(); app.buttons["key-0"].tap(); app.buttons["key-完成"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["daily-summary"].firstMatch.exists)
        let row = app.descendants(matching: .any)["finance-row-tao"].firstMatch
        row.swipeLeft(); app.buttons["退款"].tap()
        app.buttons["refund-all"].tap()
        XCTAssertTrue(app.staticTexts["¥ 10.00"].exists)
        app.buttons["key-完成"].tap()
        XCTAssertTrue(app.staticTexts["+10.00"].exists)
        app.tabBars.buttons["便便"].tap()
        let start = app.buttons["开始便便"]
        XCTAssertGreaterThan(start.frame.midX, app.frame.midX)
        start.tap(); app.buttons["结束并记录"].tap()
        let save = app.buttons["save-bowel"]
        XCTAssertGreaterThan(save.frame.midX, app.frame.midX)
        XCTAssertGreaterThan(save.frame.maxY, app.frame.height * 0.7)
        app.swipeUp()
        let blood = app.buttons["bowel-厕纸血迹-没有"]
        XCTAssertTrue(blood.exists)
        XCTAssertLessThanOrEqual(blood.frame.height, 48)
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "Compact bowel and bottom save"; shot.lifetime = .keepAlways; add(shot)
        save.tap()
    }

    func testAnalysisAndSettingsGrid() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--test-store", UUID().uuidString]
        app.launch()
        app.buttons["new-entry"].tap()
        app.textFields["entry-tag"].tap(); app.textFields["entry-tag"].typeText("寿司郎")
        app.buttons["标签完成"].tap()
        app.buttons["key-1"].tap(); app.buttons["key-0"].tap(); app.buttons["key-0"].tap()
        app.buttons["key-完成"].tap()
        app.tabBars.buttons["设置"].tap()
        let settingsShot = XCTAttachment(screenshot: app.screenshot())
        settingsShot.name = "Settings icon grid"; settingsShot.lifetime = .keepAlways; add(settingsShot)
        app.buttons["金额分析"].tap()
        XCTAssertTrue(app.navigationBars["金额分析"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["analysis-total"].label, "¥ 100.00")
        app.segmentedControls.buttons["收入"].tap()
        XCTAssertEqual(app.staticTexts["analysis-total"].label, "¥ 0.00")
        app.segmentedControls.buttons["支出"].tap()
        app.segmentedControls.buttons["年"].tap()
        XCTAssertEqual(app.staticTexts["analysis-total"].label, "¥ 100.00")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.navigationBars["设置"].exists)
        app.buttons["大类分析"].tap()
        XCTAssertTrue(app.staticTexts["analysis-total"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["analysis-total"].label, "¥ 100.00")
        let group = app.buttons["analysis-group-食物"]
        if !group.isHittable { app.swipeUp() }
        group.tap()
        XCTAssertTrue(app.staticTexts["−100.00"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["标签分析"].tap()
        app.segmentedControls.buttons["年"].tap()
        let search = app.textFields["analysis-tag-search"]
        search.tap(); search.typeText("寿司郎\n")
        XCTAssertEqual(app.staticTexts["analysis-total"].label, "¥ 100.00")
        let tagShot = XCTAttachment(screenshot: app.screenshot())
        tagShot.name = "Annual tag analysis"; tagShot.lifetime = .keepAlways; add(tagShot)
        app.segmentedControls.buttons["区间"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["analysis-start-date"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["analysis-end-date"].firstMatch.exists)
    }

    func testSettingsNavigationAndRecurringConfirmation() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--test-store", UUID().uuidString]
        app.launch()
        app.tabBars.buttons["设置"].tap()
        XCTAssertTrue(app.navigationBars["设置"].waitForExistence(timeout: 5))
        app.buttons["账户与余额"].tap()
        XCTAssertTrue(app.navigationBars["账户与余额"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.navigationBars["设置"].waitForExistence(timeout: 5))
        app.buttons["固定收支"].tap()
        app.buttons["add-recurring"].tap()
        app.textFields["名称，如房租"].tap(); app.textFields["名称，如房租"].typeText("房租测试")
        app.textFields["金额"].tap(); app.textFields["金额"].typeText("100")
        app.textFields["小标签"].tap(); app.textFields["小标签"].typeText("固定房租")
        app.navigationBars.buttons["保存"].tap()
        XCTAssertTrue(app.buttons["confirm-recurring-房租测试"].waitForExistence(timeout: 5))
        app.tabBars.buttons["记账"].tap()
        XCTAssertFalse(app.staticTexts["−100.00"].exists)
        app.buttons["pending-recurring"].tap()
        app.buttons["confirm-recurring-房租测试"].tap()
        app.alerts.buttons["确认记账"].tap()
        XCTAssertFalse(app.buttons["confirm-recurring-房租测试"].exists)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["new-entry"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["−100.00"].exists)
        app.terminate(); app.launch()
        XCTAssertTrue(app.staticTexts["−100.00"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["pending-recurring"].exists)
    }

    func testSwipeActionsForBothRecordTypes() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--test-store", UUID().uuidString]
        app.launch()
        app.buttons["new-entry"].tap()
        app.textFields["entry-tag"].tap()
        app.textFields["entry-tag"].typeText("左滑测试")
        app.buttons["标签完成"].tap()
        app.buttons["key-1"].tap(); app.buttons["key-0"].tap()
        app.buttons["key-完成"].tap()
        let row = app.descendants(matching: .any).matching(identifier: "finance-row-左滑测试").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.swipeLeft()
        for title in ["复制", "退款", "删除", "修改"] { XCTAssertTrue(app.buttons[title].exists) }
        app.buttons["复制"].tap()
        XCTAssertEqual(app.textFields["entry-tag"].value as? String, "左滑测试")
        XCTAssertTrue(app.staticTexts["¥ 10.00"].exists)
        app.navigationBars.buttons["取消"].tap()
        row.swipeLeft(); app.buttons["退款"].tap()
        app.buttons["key-1"].tap(); app.buttons["key-完成"].tap()
        XCTAssertTrue(app.staticTexts["+1.00"].waitForExistence(timeout: 5))
        let original = app.cells.containing(.staticText, identifier: "−10.00").firstMatch
        original.swipeLeft(); app.buttons["修改"].tap()
        XCTAssertTrue(app.textFields["entry-tag"].waitForExistence(timeout: 5))
        app.buttons["key-完成"].tap()
        original.swipeLeft(); app.buttons["删除"].tap()
        app.alerts.buttons["删除记录"].tap()
        XCTAssertFalse(app.staticTexts["−10.00"].exists)
        XCTAssertFalse(app.staticTexts["+1.00"].exists)
        app.tabBars.buttons["便便"].tap()
        app.buttons["开始便便"].tap(); app.buttons["结束并记录"].tap()
        app.buttons["save-bowel"].tap()
        let bowel = app.buttons["bowel-record-row"].firstMatch
        if !bowel.isHittable { app.swipeUp() }
        bowel.swipeLeft(); app.buttons["修改"].tap()
        app.buttons["bowel-形态-颗粒状"].tap()
        app.buttons["save-bowel"].tap()
        if !bowel.isHittable { app.swipeUp() }
        XCTAssertTrue(app.staticTexts["颗粒状 · 咖啡色"].exists)
        bowel.swipeLeft(); app.buttons["删除"].tap()
        app.alerts.buttons["删除记录"].tap()
        XCTAssertFalse(bowel.exists)
    }

    func testBowelInlineIconsAndNoResult() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--test-store", UUID().uuidString]
        app.launch()
        app.tabBars.buttons["便便"].tap()
        app.buttons["开始便便"].tap()
        app.buttons["结束并记录"].tap()
        let watery = app.buttons["bowel-形态-水样"]
        XCTAssertTrue(watery.waitForExistence(timeout: 5))
        watery.tap()
        XCTAssertEqual(watery.value as? String, "已选")
        app.segmentedControls.buttons["拟真"].tap()
        XCTAssertEqual(watery.value as? String, "已选")
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Bowel inline realistic icons"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.navigationBars.buttons["返回"].tap()
        app.buttons["没拉出来，结束计时"].tap()
        app.alerts.buttons["结束计时"].tap()
        XCTAssertTrue(app.buttons["开始便便"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["从今天开始好好记录"].exists)
        app.terminate(); app.launch()
        app.tabBars.buttons["便便"].tap()
        XCTAssertTrue(app.buttons["开始便便"].exists)
        app.buttons["开始便便"].tap()
        app.buttons["结束并记录"].tap()
        XCTAssertTrue(app.segmentedControls.buttons["拟真"].isSelected)
        XCTAssertEqual(app.buttons["bowel-形态-香蕉形"].value as? String, "已选")
        app.segmentedControls.buttons["金渐层涂鸦"].tap()
        let doodle = XCTAttachment(screenshot: app.screenshot())
        doodle.name = "Bowel inline doodle icons"
        doodle.lifetime = .keepAlways
        add(doodle)
    }

    func testTransferControlsStayInsideScreen() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--test-store", UUID().uuidString]
        app.launch()
        XCTAssertTrue(app.buttons["new-entry"].waitForExistence(timeout: 20))
        app.buttons["new-entry"].tap()
        app.segmentedControls.buttons["转账"].tap()
        let screen = app.windows.firstMatch.frame
        for identifier in ["transfer-source", "transfer-destination", "transfer-date", "key-完成"] {
            let control = app.descendants(matching: .any).matching(identifier: identifier).firstMatch
            XCTAssertTrue(control.waitForExistence(timeout: 5), identifier)
            XCTAssertTrue(control.isHittable, identifier)
            XCTAssertGreaterThanOrEqual(control.frame.minX, screen.minX, identifier)
            XCTAssertLessThanOrEqual(control.frame.maxX, screen.maxX, identifier)
        }
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testExpensePersistsAndBowelTimerSurvivesRelaunch() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--test-store", UUID().uuidString]
        app.launch()
        XCTAssertTrue(app.buttons["new-entry"].waitForExistence(timeout: 20))
        app.buttons["new-entry"].tap()
        app.buttons["category-食物"].tap()
        XCTAssertTrue(app.buttons["本次只记大类"].waitForExistence(timeout: 5))
        app.buttons["本次只记大类"].tap()
        let tag = app.textFields["entry-tag"]
        tag.tap(); tag.typeText("测试餐厅")
        app.buttons["标签完成"].tap()
        XCTAssertFalse(app.textFields["备注（可选）"].exists)
        app.buttons["choose-tag"].tap()
        XCTAssertTrue(app.textFields["添加小标签"].waitForExistence(timeout: 5))
        app.buttons["关闭标签选择"].tap()
        for digit in ["1", ".", "2", "3"] { app.buttons["key-" + digit].tap() }
        app.buttons["key-完成"].tap()
        XCTAssertTrue(app.staticTexts["测试餐厅"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["−1.23"].exists)
        app.terminate(); app.launch()
        XCTAssertTrue(app.staticTexts["测试餐厅"].waitForExistence(timeout: 10))
        app.tabBars.buttons["便便"].tap()
        app.buttons["开始便便"].tap()
        XCTAssertTrue(app.buttons["结束并记录"].waitForExistence(timeout: 5))
        app.terminate(); app.launch()
        app.tabBars.buttons["便便"].tap()
        XCTAssertTrue(app.buttons["结束并记录"].waitForExistence(timeout: 5))
        app.buttons["结束并记录"].tap()
        app.buttons["save-bowel"].tap()
        XCTAssertTrue(app.buttons["开始便便"].waitForExistence(timeout: 5))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}
