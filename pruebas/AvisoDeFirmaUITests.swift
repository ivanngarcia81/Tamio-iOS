import XCTest

/// **El aviso de campos incompletos sale DONDE se pulsa, no dos pantallas
/// después.**
///
/// Lo vio Iván: tocaba "Firmar y enviar" con la carta vacía y no pasaba nada; el
/// aviso aparecía de golpe al volver atrás, encima del carrusel de plantillas.
///
/// La causa: el `.alert` colgaba de la vista RAÍZ de `CartasView`, y el botón
/// vive en el editor, que se abre EMPUJADO con `navigationDestination`. Una
/// alerta colgada de una vista que ya no está delante no se presenta — espera.
///
/// Esta prueba no puede pasar por accidente: exige que el aviso esté visible
/// **sin volver atrás**.
final class AvisoDeFirmaUITests: XCTestCase {
    /// **Solo iPhone**: llega al editor por la pestaña Secretary. En el iPad
    /// físico (23-sep) daba roja con «No matches found for Descendants matching
    /// type TabBar» o su equivalente, que no dice nada de la app: es la omisión
    /// de las de iPad, al revés.
    override func setUpWithError() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "solo iPhone")
    }

    func testElAvisoSaleEnElEditor() {
        let app = XCUIApplication()
        app.launchArguments = ["-prefs.bienvenidaVista", "1",
                               "-prefs.idioma", "ingles", "-AppleLanguages", "(en)",
                               "-prefs.tema", "claro"]
        // Candado apagado por argumento: un bloqueo guardado en el aparato
        // la dejaría tapada (ver LEEME.md, «El candado y las corridas»).
        app.launchArguments += ["-bloqueo.biometrico", "NO"]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 25))
        sleep(2)

        XCTAssertTrue(app.tabBars.buttons["Secretary"].waitForExistence(timeout: 20))
        app.tabBars.buttons["Secretary"].tap(); sleep(2)

        let fila = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'Letters'")).firstMatch
        for _ in 0..<6 {
            if fila.exists && fila.isHittable { break }
            app.swipeUp(velocity: .slow); sleep(1)
        }
        guard fila.waitForExistence(timeout: 8) else {
            print("HUB:" + app.buttons.allElementsBoundByIndex.prefix(25)
                    .map { String($0.label.prefix(26)) }.joined(separator: "|"))
            fflush(stdout)
            XCTFail("no está «Letters & transfers»"); return
        }
        fila.tap(); sleep(3)

        // Abrir una plantilla: la tarjeta entera es el botón.
        let tarjeta = app.buttons.matching(NSPredicate(
            format: "label CONTAINS 'letter' OR label CONTAINS 'Certificate' OR label CONTAINS 'Transfer'"))
            .firstMatch
        guard tarjeta.waitForExistence(timeout: 10) else {
            print("CARTAS:" + app.buttons.allElementsBoundByIndex.prefix(25)
                    .map { String($0.label.prefix(30)) }.joined(separator: "|"))
            fflush(stdout)
            XCTFail("no hay ninguna plantilla que abrir"); return
        }
        tarjeta.tap(); sleep(3)

        let firmar = app.buttons.matching(NSPredicate(
            format: "label BEGINSWITH 'Sign' OR label BEGINSWITH 'Firmar'")).firstMatch
        guard firmar.waitForExistence(timeout: 8) else {
            print("EDITOR:" + app.buttons.allElementsBoundByIndex.prefix(25)
                    .map { String($0.label.prefix(26)) }.joined(separator: "|"))
            fflush(stdout)
            XCTFail("no está «Firmar y enviar» en el editor"); return
        }
        firmar.tap()
        sleep(2)
        print("MARCA:aviso-de-firma"); fflush(stdout)

        // **Sin volver atrás**: el aviso tiene que estar AQUÍ.
        let aviso = app.alerts.firstMatch
        XCTAssertTrue(aviso.waitForExistence(timeout: 6),
                      "el aviso no salió en el editor: sigue colgado de la vista de atrás")
        print("AVISO:\(aviso.label)"); fflush(stdout)
        Thread.sleep(forTimeInterval: 2.5)
    }
}
