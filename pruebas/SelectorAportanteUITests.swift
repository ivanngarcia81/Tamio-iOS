import XCTest

/// Mirar la hoja de captura con la app corriendo: que el selector de aportante
/// ofrezca el padrón del teléfono. Solo navega y fotografía; no guarda nada.
final class SelectorAportanteUITests: XCTestCase {
    /// **Solo iPhone**: llega a la hoja de captura por la pestaña Treasury. En el
    /// iPad físico (23-sep) daba roja con «No matches found for Descendants
    /// matching type TabBar» o su equivalente, que no dice nada de la app: es la
    /// omisión de las de iPad, al revés.
    override func setUpWithError() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "solo iPhone")
    }

    func testElSelectorDeAportanteOfreceElPadron() {
        let app = XCUIApplication()
        // Candado apagado por argumento: un bloqueo guardado en el aparato
        // la dejaría tapada (ver LEEME.md, «El candado y las corridas»).
        app.launchArguments += ["-bloqueo.biometrico", "NO"]
        app.launch()
        XCTAssertTrue(app.buttons["Treasury"].waitForExistence(timeout: 20))
        app.buttons["Treasury"].tap()

        let mov = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Transactions'")).firstMatch
        XCTAssertTrue(mov.waitForExistence(timeout: 10), marca("no está la fila de Movimientos"))
        mov.tap()

        let nuevo = app.buttons["New"].firstMatch
        XCTAssertTrue(nuevo.waitForExistence(timeout: 10), marca("no está el +"))
        nuevo.tap()

        // La hoja de captura. El selector de aportante es la fila que la
        // pantalla llama "Contributor"/"Member".
        let selector = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'Contributor'")).firstMatch
        XCTAssertTrue(selector.waitForExistence(timeout: 10), marca("no está el selector"))
        selector.tap()
        sleep(2)
        // Lo que ofrece el menú: tiene que ser el padrón del teléfono.
        let opciones = app.buttons.allElementsBoundByIndex.map(\.label)
        print("### opciones: \(opciones)")
        print("### MARCA-LISTA")
        sleep(8)
    }

    private func marca(_ s: String) -> String { "### \(s)" }
}
