import XCTest

/// Que la lupa esté donde Iván la pidió: escondida hasta tirar hacia abajo.
final class BarraMembresiaUITests: XCTestCase {
    /// **Solo iPhone**: mira el cajón de la lupa del teléfono, y llega por la
    /// pestaña Secretary. En el iPad físico (23-sep) daba roja con «No matches
    /// found for Descendants matching type TabBar» o su equivalente, que no dice
    /// nada de la app: es la omisión de las de iPad, al revés.
    override func setUpWithError() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "solo iPhone")
    }

    func testElCajonDeLaLupa() {
        let app = XCUIApplication()
        // Candado apagado por argumento: un bloqueo guardado en el aparato
        // la dejaría tapada (ver LEEME.md, «El candado y las corridas»).
        app.launchArguments += ["-bloqueo.biometrico", "NO"]
        app.launch()
        XCTAssertTrue(app.buttons["Secretary"].waitForExistence(timeout: 20))
        app.buttons["Secretary"].tap()
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Membership,'"))
            .firstMatch.tap()
        sleep(3)

        XCTAssertFalse(app.searchFields.firstMatch.exists,
                       "### el campo no puede estar puesto de entrada")
        // Tirar hacia abajo, DESPACIO y por coordenadas: un `swipeDown` sobre
        // una fila lo interpreta como toque y abre la ficha.
        let arriba = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.30))
        let abajo  = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75))
        arriba.press(forDuration: 0.2, thenDragTo: abajo)
        sleep(2)
        print("### campo tras tirar: \(app.searchFields.allElementsBoundByIndex.map { $0.placeholderValue ?? $0.label })")
        print("### BARRA: \(app.navigationBars.firstMatch.buttons.allElementsBoundByIndex.map(\.label))")
        print("### MARCA-CAJON")
        sleep(5)
    }
}
