import XCTest

/// **Capturas del APARATO, adjuntas al `.xcresult`.**
///
/// `simctl io screenshot` solo vale para el simulador y `devicectl` no captura
/// pantalla, así que hasta hoy todo lo visual del iPhone físico se verificaba
/// con los ojos de Iván. Esta prueba no afirma nada: recorre Reportes y Cartas
/// en claro y en oscuro y adjunta una captura de cada parada con
/// `XCTAttachment`, que sobrevive en el `.xcresult`. `pruebas/fotos.sh` las
/// saca a PNG y `pruebas/tarjeta.py` mide la tarjeta: cuerpo, filo, sombra y
/// contraste del título. Con eso se compara un material contra otro en la
/// pantalla de verdad, que es P3 y devuelve otro píxel del que se pidió.
///
/// El tema se fuerza por argumento (`-prefs.tema`), como en
/// `ChipDePeriodoUITests`: en un aparato físico no hay forma de cambiar la
/// apariencia del sistema desde el Mac.
///
/// En vertical. Los adjuntos en apaisado salen rotados y recortados (§0.0 del
/// traspaso); aquí no hace falta girar nada.
final class MaterialesEnAparato: XCTestCase {

    func lanzar(tema: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-prefs.idioma", "ingles", "-AppleLanguages", "(en)",
                                "-prefs.tema", tema]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 25))
        sleep(2)
        return app
    }

    func foto(_ app: XCUIApplication, _ nombre: String) {
        let adjunto = XCTAttachment(screenshot: app.screenshot())
        adjunto.name = nombre
        adjunto.lifetime = .keepAlways
        add(adjunto)
        print("FOTO:\(nombre) \(app.frame.size)")
        fflush(stdout)
    }

    /// Baja por el hub hasta que la fila se pueda tocar. Las filas bajo el
    /// pliegue no están en el árbol hasta que se desplaza (§3 del traspaso).
    func abrirFila(_ app: XCUIApplication, _ prefijo: String) -> Bool {
        let fila = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", prefijo)).firstMatch
        for intento in 0..<6 {
            if fila.waitForExistence(timeout: intento == 0 ? 4 : 1) && fila.isHittable {
                fila.tap(); sleep(3); return true
            }
            app.swipeUp(velocity: .slow); sleep(1)
        }
        print("HUB:" + app.buttons.allElementsBoundByIndex.prefix(25)
                .map { String($0.label.prefix(24)) }.joined(separator: "|"))
        fflush(stdout)
        return false
    }

    func recorrido(tema: String) {
        let app = lanzar(tema: tema)
        app.tabBars.buttons["Treasury"].tap(); sleep(2)
        guard abrirFila(app, "Reports") else { XCTFail("no se alcanzó Reportes"); return }
        foto(app, "reportes-\(tema)")

        app.tabBars.buttons["Secretary"].tap(); sleep(2)
        guard abrirFila(app, "Letters & transfers") else { XCTFail("no se alcanzó Cartas"); return }
        sleep(2)   // el carrusel termina de asentarse
        foto(app, "cartas-\(tema)")
    }

    func testClaro()  { recorrido(tema: "claro") }
    func testOscuro() { recorrido(tema: "oscuro") }
}
