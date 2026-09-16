import XCTest
final class SmokeTests: XCTestCase {
    func testExpensePersistsAndBowelTimerSurvivesRelaunch() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--test-store", UUID().uuidString]
        app.launch()
        XCTAssertTrue(app.buttons["new-entry"].waitForExistence(timeout: 20))
        app.buttons["new-entry"].tap()
        app.buttons["category-食物"].tap()
        let tag = app.textFields["添加小标签"]
        XCTAssertTrue(tag.waitForExistence(timeout: 5))
        tag.tap(); tag.typeText("测试餐厅")
        app.buttons["选择"].tap()
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
