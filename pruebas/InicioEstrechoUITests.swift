import XCTest

/// Los cuatro indicadores de Inicio en una columna estrecha (iPad mini en
/// vertical con la sidebar fijada): ninguna cifra puede partirse.
final class InicioEstrecho: XCTestCase {
    func testLasCifrasNoSePartenEnLaColumnaEstrecha() {
        let app = XCUIApplication()
        app.launchArguments += ["-prefs.idioma", "ingles", "-AppleLanguages", "(en)"]
        app.launch(); sleep(2)
        XCUIDevice.shared.orientation = .portrait; sleep(2)
        let mostrar = app.buttons["Show Sidebar"].firstMatch
        if mostrar.exists { mostrar.tap(); sleep(1) }
        let inicio = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Home'")).firstMatch
        if inicio.exists { inicio.tap(); sleep(3) }
        print("MARCA:I-inicio-estrecho"); fflush(stdout); Thread.sleep(forTimeInterval: 3)

        // El saludo, entero: es lo único personal de la pantalla.
        XCTAssertTrue(app.staticTexts["Good morning, Iván"].exists,
                      "### el saludo salió recortado")
        // Los rótulos enteros, no "Cash on h…".
        for r in ["Cash on hand", "Period income", "Period expenses", "To review"] {
            XCTAssertTrue(app.staticTexts[r].exists, "### falta el rótulo \(r)")
        }
        // Y las cifras en UN renglón: una tarjeta de 96 pt de alto con una
        // cifra partida pasa de 30 pt de texto.
        for c in ["$28,633", "$39,063", "$7,518"] {
            let e = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", c)).firstMatch
            XCTAssertTrue(e.exists, "### falta la cifra \(c)")
            XCTAssertLessThan(e.frame.height, 45, "### \(c) salió en dos renglones: \(e.frame)")
        }
        let bandeja = app.staticTexts["13"].firstMatch
        XCTAssertTrue(bandeja.exists, "### el conteo de la bandeja se partió")
        XCTAssertLessThan(bandeja.frame.height, 50, "### el 13 salió en dos renglones: \(bandeja.frame)")
        XCUIDevice.shared.orientation = .portrait
    }
}
