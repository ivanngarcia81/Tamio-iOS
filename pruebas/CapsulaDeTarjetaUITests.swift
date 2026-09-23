import XCTest

/// **¿La cápsula de dentro de la tarjeta recibe el toque?**
///
/// Las tarjetas de Reportes son un `Button` y llevan OTRO `Button` dentro: la
/// cápsula de "Vista previa PDF". Ese anidado existe en Cartas desde antes,
/// pero allí la cápsula ("Redactar") y la tarjeta hacen LO MISMO: si el toque
/// de dentro nunca hubiera llegado, nadie se habría enterado. En Reportes hacen
/// cosas distintas —la tarjeta abre el reporte, la cápsula enseña la hoja del
/// PDF—, así que aquí sí se nota, y es lo único de ese cambio que una captura
/// no puede demostrar.
///
/// **La cápsula no se busca por rótulo.** La tarjeta se lee de una pieza
/// (`accessibilityElement(children: .combine)`), así que sus hijos no están en
/// el árbol de accesibilidad. Se toca por coordenada: dx 0.308, dy 0.722 del
/// marco de la tarjeta, medidos sobre una captura real y no estimados.
///
/// **Y lleva control.** Sin él, una prueba que tocara cualquier sitio y viera
/// la hoja del PDF pasaría igual: hay que comprobar TAMBIÉN que tocar la
/// tarjeta por arriba hace lo OTRO. Es la cuarta forma de que una prueba dé
/// verde sin probar nada.
final class CapsulaDeTarjeta: XCTestCase {
    /// **Solo iPhone**: llega a Reportes por la pestaña Treasury. En el iPad
    /// físico (23-sep) daba roja con «No matches found for Descendants matching
    /// type TabBar» o su equivalente, que no dice nada de la app: es la omisión
    /// de las de iPad, al revés.
    override func setUpWithError() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "solo iPhone")
    }

    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments += ["-prefs.idioma", "ingles", "-AppleLanguages", "(en)"]
        // Candado apagado por argumento: un bloqueo guardado en el aparato
        // la dejaría tapada (ver LEEME.md, «El candado y las corridas»).
        app.launchArguments += ["-bloqueo.biometrico", "NO"]
        app.launch()
        _ = app.wait(for: .runningForeground, timeout: 25)
        sleep(2)
    }

    /// Deja la app en la pantalla de Reportes y devuelve la tarjeta del estado
    /// financiero. `nil` si no se llega: quien llame debe fallar.
    func tarjeta() -> XCUIElement? {
        app.tabBars.buttons["Treasury"].tap(); sleep(2)
        let fila = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'Reports'")).firstMatch
        for _ in 0..<6 {
            if fila.exists && fila.isHittable { break }
            app.swipeUp(velocity: .slow); sleep(1)
        }
        guard fila.waitForExistence(timeout: 8) else {
            print("HUB:" + app.buttons.allElementsBoundByIndex.prefix(25)
                    .map { String($0.label.prefix(24)) }.joined(separator: "|"))
            fflush(stdout)
            return nil
        }
        fila.tap(); sleep(3)
        let t = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Financial statement'")).firstMatch
        guard t.waitForExistence(timeout: 8) else {
            print("REPORTES:" + app.buttons.allElementsBoundByIndex.prefix(25)
                    .map { String($0.label.prefix(24)) }.joined(separator: "|"))
            fflush(stdout)
            return nil
        }
        return t
    }

    func barras() -> [String] {
        app.navigationBars.allElementsBoundByIndex.map { $0.identifier }
    }

    func testLaCapsulaAbreElPDFYLaTarjetaAbreElReporte() {
        // --- 1. La cápsula.
        guard let t = tarjeta() else { XCTFail("no se llegó a la tarjeta"); return }
        print("TARJETA marco=\(t.frame)"); fflush(stdout)

        t.coordinate(withNormalizedOffset: CGVector(dx: 0.308, dy: 0.722)).tap()
        sleep(3)
        print("TRAS-CÁPSULA barras=" + barras().joined(separator: "|")); fflush(stdout)
        let hoja = app.navigationBars["PDF preview"]
        XCTAssertTrue(hoja.waitForExistence(timeout: 6),
                      "la cápsula no abrió la vista previa; barras: \(barras())")

        // Cerrar la hoja para dejar la pantalla como estaba.
        if app.buttons["Close"].exists { app.buttons["Close"].tap(); sleep(2) }

        // --- 2. EL CONTROL: tocar la tarjeta por ARRIBA tiene que hacer lo otro.
        let t2 = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Financial statement'")).firstMatch
        guard t2.waitForExistence(timeout: 8) else {
            XCTFail("no se volvió a la pantalla de Reportes"); return
        }
        t2.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2)).tap()
        sleep(3)
        print("TRAS-TARJETA barras=" + barras().joined(separator: "|")); fflush(stdout)
        XCTAssertFalse(app.navigationBars["PDF preview"].exists,
                       "tocar la tarjeta abrió la hoja del PDF: entonces la prueba de arriba no demuestra nada")
        XCTAssertFalse(t2.exists,
                       "tocar la tarjeta no llevó a ninguna parte: sigue en la lista de reportes")
    }
}
