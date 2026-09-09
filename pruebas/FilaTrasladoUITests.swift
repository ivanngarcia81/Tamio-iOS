import XCTest

/// La fila del padrón con un traslado abierto: la pastilla entera y la fila a
/// la misma altura que sus vecinas.
final class FilaTraslado: XCTestCase {

    func testLaPastillaNoSeRecortaNiEstiraLaFila() {
        let app = XCUIApplication()
        app.launchArguments += ["-prefs.idioma", "ingles", "-AppleLanguages", "(en)"]
        app.launch(); sleep(2)
        XCUIDevice.shared.orientation = .landscapeLeft; sleep(3)
        let m = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Membership'")).firstMatch
        if !(m.exists && m.isHittable) {
            app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'sidebar'")).firstMatch.tap(); sleep(1)
        }
        m.tap(); sleep(3)
        print("MARCA:T-membresia"); fflush(stdout); Thread.sleep(forTimeInterval: 3)

        let pastilla = app.staticTexts["Transfer in progress"].firstMatch
        XCTAssertTrue(pastilla.waitForExistence(timeout: 5), "### no encontré la pastilla de traslado")
        // Otra pastilla de la misma clase, para saber a qué tamaño se dibujan
        // las que sí caben.
        let activo = app.staticTexts["Active"].firstMatch
        print("### traslado \(pastilla.frame) · activo \(activo.frame)")
        XCTAssertEqual(pastilla.frame.height, activo.frame.height, accuracy: 1.0,
                       "### la pastilla de traslado se dibuja a otro tamaño: \(pastilla.frame)")
        // "Transfer in progress" a `.caption` mide unos 128 pt. Recortada o
        // encogida al 75 % se queda por debajo de 110.
        XCTAssertGreaterThan(pastilla.frame.width, 110,
                             "### la pastilla sale recortada o encogida: \(pastilla.frame)")

        // La fila SÍ es más alta que las demás, y está bien: lleva una
        // pastilla más. Lo que no puede es dibujarla a otro tamaño.
        let filas = app.cells.allElementsBoundByIndex.filter { $0.frame.width > 200 && $0.frame.height > 40 }
        print("### altos de fila \(filas.map { $0.frame.height })")
        XCUIDevice.shared.orientation = .portrait
    }
}
