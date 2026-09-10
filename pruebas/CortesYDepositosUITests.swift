import XCTest

/// **Cortes y depósitos, que la pasada del 10-sep LISTÓ pero no ABRIÓ.**
///
/// Es la diferencia que ya costó cara con la bandeja «Por revisar»: una lista
/// que se dibuja no dice nada de si sus acciones hacen algo. Aquí se entra a la
/// pantalla, se abre el primer corte y el primer depósito, y se vuelca lo que
/// hay —con `isHittable`, que es lo único que distingue lo que se ve de lo que
/// solo está en el árbol.
///
/// No afirma casi nada a propósito: en un aparato con datos de verdad no se
/// sabe cuántos cortes hay. Lo que sí afirma es que **si hay filas, abrirlas
/// cambia la pantalla** — que es justo lo que estaba roto en la bandeja.
final class CortesYDepositosUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments += ["-prefs.idioma", "ingles", "-AppleLanguages", "(en)"]
        app.launch()
        sleep(3)
    }

    private func describir(_ q: XCUIElementQuery) -> String {
        q.allElementsBoundByIndex.prefix(40).map {
            "\($0.label)[\(Int($0.frame.minY))]"
            + ($0.isEnabled ? "" : "·OFF") + ($0.isHittable ? "" : "·NOHIT")
        }.joined(separator: " ‖ ")
    }

    private func volcado(_ titulo: String) {
        print(">>> \(titulo)")
        print("  BARRA: \(describir(app.navigationBars.buttons))")
        print("  BOTONES: \(describir(app.buttons))")
        print("  TEXTOS: \(describir(app.staticTexts))")
        fflush(stdout)
    }

    @discardableResult
    private func abrirFila(_ prefijo: String) -> Bool {
        let p = NSPredicate(format: "label BEGINSWITH %@", prefijo)
        for intento in 0..<5 {
            let e = app.buttons.matching(p).firstMatch
            if e.waitForExistence(timeout: intento == 0 ? 5 : 1) && e.isHittable {
                e.tap(); sleep(3); return true
            }
            app.swipeUp(velocity: .slow); sleep(1)
        }
        print("  !! no encontré la fila \(prefijo)")
        return false
    }

    /// **iPhone y iPad no navegan igual, y por eso esto no es un `if` cosmético.**
    /// El teléfono tiene barra de pestañas y un hub de Tesorería con Depósitos
    /// dentro; el iPad tiene sidebar y Depósitos cuelga directamente de ella.
    /// La primera versión de esta prueba solo sabía de pestañas y en el iPad
    /// fallaba con "No matches found for Descendants matching type TabBar",
    /// que parece un fallo del producto y no lo es.
    private func irADepositos() -> Bool {
        let pestana = app.tabBars.buttons["Treasury"]
        if pestana.waitForExistence(timeout: 6) {
            print("QA-FORMA:telefono")
            pestana.tap(); sleep(2)
            volcado("hub Tesorería")
            return abrirFila("Deposits")
        }
        print("QA-FORMA:ipad")
        volcado("sidebar")
        // En la sidebar la fila es un botón con su título tal cual.
        let fila = app.buttons["Deposits"]
        if fila.waitForExistence(timeout: 6) && fila.isHittable {
            fila.tap(); sleep(3); return true
        }
        return abrirFila("Deposits")
    }

    func testAbrirDepositosYSusCortes() {
        XCTAssertTrue(irADepositos(), "no se pudo llegar a Depósitos")
        volcado("Depósitos")

        let celdas = app.cells.allElementsBoundByIndex.filter(\.isHittable)
        print("QA-CELDAS-DEPOSITOS:\(celdas.count)")

        let antes = app.staticTexts.allElementsBoundByIndex.map(\.label).joined()

        // La 0 suele ser la cabecera de sección (punto 2 del §3).
        guard let primera = celdas.dropFirst().first else {
            print("QA-AVISO: no hay filas tocables en Depósitos; nada que abrir")
            return
        }
        primera.tap(); sleep(3)
        volcado("primer corte abierto")
        let despues = app.staticTexts.allElementsBoundByIndex.map(\.label).joined()
        XCTAssertNotEqual(antes, despues,
                          "### se abrió una fila de Depósitos y la pantalla NO cambió")
    }
}
