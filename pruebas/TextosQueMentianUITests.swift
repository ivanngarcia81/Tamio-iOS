import XCTest

/// **Lo que de estas tres frases se puede comprobar mirando.**
///
/// El subtítulo de Actas **no**, y conviene saber por qué: los datos de ejemplo
/// son los que inspiraron la frase escrita a mano, así que el texto calculado
/// sale idéntico —"Minutes 2026-08 in draft"— y la pantalla se ve igual antes y
/// después. La diferencia solo aparece cambiando el padrón de actas, que es lo
/// que hacen las pruebas unitarias con tres listas distintas.
///
/// Lo que sí se ve es el "Guardado hace 2 minutos": las actas de ejemplo no
/// tienen fecha de guardado, así que ahora no debe salir nada bajo el borrador.
final class TextosQueMentianUITests: XCTestCase {
    /// **Solo iPhone**: llega a Actas bajando por el hub de Secretaría del
    /// teléfono. En el iPad físico (23-sep) daba roja con «No matches found for
    /// Descendants matching type TabBar» o su equivalente, que no dice nada de la
    /// app: es la omisión de las de iPad, al revés.
    override func setUpWithError() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "solo iPhone")
    }

    func testElBorradorYaNoDiceUnaHoraInventada() {
        let app = XCUIApplication()
        // Candado apagado por argumento: un bloqueo guardado en el aparato
        // la dejaría tapada (ver LEEME.md, «El candado y las corridas»).
        app.launchArguments += ["-bloqueo.biometrico", "NO"]
        app.launch()
        XCTAssertTrue(app.buttons["Secretary"].waitForExistence(timeout: 30))
        app.buttons["Secretary"].tap()
        sleep(2)
        app.swipeUp(); sleep(1); app.swipeUp(); sleep(2)
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Minutes'")).firstMatch.tap()
        sleep(3)
        app.cells.firstMatch.tap()
        sleep(3)
        XCTAssertFalse(app.staticTexts["Saved 2 minutes ago"].exists,
                       "### sigue la hora escrita a mano")
    }
}
