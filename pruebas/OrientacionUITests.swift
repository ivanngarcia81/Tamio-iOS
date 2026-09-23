import XCTest

/// **El teléfono no gira.** En apaisado, un iPhone grande pasa a clase de
/// tamaño regular y la app se dibuja como en iPad —dos columnas—, así que
/// girarlo daba una app que no es la del teléfono.
final class OrientacionUITests: XCTestCase {
    /// **Solo iPhone**: prueba que el TELÉFONO no gira; el iPad sí debe girar. En
    /// el iPad físico (23-sep) daba roja con «No matches found for Descendants
    /// matching type TabBar» o su equivalente, que no dice nada de la app: es la
    /// omisión de las de iPad, al revés.
    override func setUpWithError() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "solo iPhone")
    }

    override func tearDown() {
        XCUIDevice.shared.orientation = .portrait
        super.tearDown()
    }

    func testElTelefonoSeQuedaEnVertical() {
        let app = XCUIApplication()
        // Candado apagado por argumento: un bloqueo guardado en el aparato
        // la dejaría tapada (ver LEEME.md, «El candado y las corridas»).
        app.launchArguments += ["-bloqueo.biometrico", "NO"]
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
