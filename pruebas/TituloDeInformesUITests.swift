import XCTest

/// **El menú del título de Informes: ¿lleva cápsula o no?**
///
/// Iván preguntó si el "General ⌄" debía ir dentro de una cápsula como los
/// botones de la derecha. Esta prueba solo abre la pantalla y se para para que
/// el shell capture: la respuesta se mira, no se afirma.
final class TituloDeInformesUITests: XCTestCase {
    /// **Solo iPhone**: llega a los informes por la pestaña Secretary. En el iPad
    /// físico (23-sep) daba roja con «No matches found for Descendants matching
    /// type TabBar» o su equivalente, que no dice nada de la app: es la omisión
    /// de las de iPad, al revés.
    override func setUpWithError() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "solo iPhone")
    }

    func testTitulo() {
        let app = XCUIApplication()
        app.launchArguments = ["-prefs.bienvenidaVista", "1",
                               "-prefs.idioma", "ingles", "-AppleLanguages", "(en)",
                               "-prefs.tema", ProcessInfo.processInfo.environment["TEMA"] ?? "claro"]
        // Candado apagado por argumento: un bloqueo guardado en el aparato
        // la dejaría tapada (ver LEEME.md, «El candado y las corridas»).
        app.launchArguments += ["-bloqueo.biometrico", "NO"]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 25))
        sleep(2)

        XCTAssertTrue(app.tabBars.buttons["Secretary"].waitForExistence(timeout: 20))
        app.tabBars.buttons["Secretary"].tap(); sleep(2)

        let fila = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'Membership reports'")).firstMatch
        for _ in 0..<6 {
            if fila.exists && fila.isHittable { break }
            app.swipeUp(velocity: .slow); sleep(1)
        }
        guard fila.waitForExistence(timeout: 8) else {
            print("HUB:" + app.buttons.allElementsBoundByIndex.prefix(25)
                    .map { String($0.label.prefix(26)) }.joined(separator: "|"))
            fflush(stdout)
            XCTFail("no está «Membership reports»"); return
        }
        fila.tap(); sleep(3)
        print("MARCA:titulo-informes"); fflush(stdout)
        Thread.sleep(forTimeInterval: 3.5)
    }
}
