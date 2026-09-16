import XCTest
final class SmokeTests: XCTestCase {
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
        app.buttons["标签填好了，输入金额"].tap()
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
        app.navigationBars.buttons["保存"].tap()
        XCTAssertTrue(app.buttons["开始便便"].waitForExistence(timeout: 5))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}
