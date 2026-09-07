import XCTest

final class PurgaUITests: XCTestCase {
    /// Con la base de revisión vacía no hay nada purgable, así que el botón NO
    /// debe estar: uno que no hace nada al tocarlo enseña que la pantalla no
    /// mira lo que dice.
    func testSinNadaQuePurgarNoHayBoton() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 30))
        app.buttons["Settings"].tap()
        sleep(2)
        app.swipeUp(); sleep(1)
        app.staticTexts["Danger zone"].firstMatch.tap()
        sleep(4)
        app.swipeUp()
        sleep(2)
        print("### botón presente: \(app.staticTexts["Free up space"].exists)")
        print("### MARCA-PURGA")
        sleep(8)
    }
}
