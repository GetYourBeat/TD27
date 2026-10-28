import XCTest

final class TD27StudioSmokeTests: XCTestCase {
    @MainActor
    func testLaunchAndBrowserWithoutHardware() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout:20))
        let browser = app.buttons["USB / SD Kit-Browser"]
        XCTAssertTrue(browser.waitForExistence(timeout:10))
        browser.click()
        XCTAssertTrue(app.buttons["100 Kitnamen lesen"].waitForExistence(timeout:5))
        XCTAssertTrue(app.buttons["Belegung lesen"].exists)
        app.buttons["Kit-Editor"].click()
        XCTAssertTrue(app.buttons["SD-Paket + Importanleitung…"].waitForExistence(timeout:5))
        let attachment = XCTAttachment(screenshot:app.screenshot())
        attachment.name = "TD27-Studio-v3.1"; attachment.lifetime = .keepAlways
        add(attachment)
        app.terminate()
    }
}
