import XCTest

/// **El teléfono no gira.** En apaisado, un iPhone grande pasa a clase de
/// tamaño regular y la app se dibuja como en iPad —dos columnas—, así que
/// girarlo daba una app que no es la del teléfono.
final class OrientacionUITests: XCTestCase {

    override func tearDown() {
        XCUIDevice.shared.orientation = .portrait
        super.tearDown()
    }

    func testElTelefonoSeQuedaEnVertical() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["Secretary"].waitForExistence(timeout: 20))

        let vertical = app.frame
        print("### vertical: \(vertical.width) x \(vertical.height)")
        XCTAssertGreaterThan(vertical.height, vertical.width)

        XCUIDevice.shared.orientation = .landscapeLeft
        sleep(3)
        let girado = app.frame
        print("### tras girar: \(girado.width) x \(girado.height)")
        print("### MARCA-GIRO")
        sleep(4)
        XCTAssertGreaterThan(girado.height, girado.width,
                             "### la app siguió al giro: sigue permitiendo apaisado")
        XCTAssertEqual(girado, vertical, "### la ventana cambió de tamaño al girar")
    }
}
