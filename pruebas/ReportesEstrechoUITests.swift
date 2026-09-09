import XCTest

/// Reportes en una columna estrecha: 13" en vertical con la sidebar (la vista
/// previa se queda en 453 pt) y iPad mini apaisado (513).
final class ReportesEstrecho: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments += ["-prefs.idioma", "ingles", "-AppleLanguages", "(en)"]
        app.launch(); sleep(2)
    }
    override func tearDown() { XCUIDevice.shared.orientation = .portrait; sleep(1) }

    func parada(_ n: String) { print("MARCA:\(n)"); fflush(stdout); Thread.sleep(forTimeInterval: 3.0) }

    func abrirReportes() {
        let r = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Reports'")).firstMatch
        if !(r.exists && r.isHittable) {
            app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'sidebar'")).firstMatch.tap(); sleep(1)
        }
        r.tap(); sleep(2)
    }

    /// Nada de la tabla puede quedar fuera de la ventana.
    func dentro(_ e: XCUIElement, _ que: String) {
        XCTAssertTrue(e.exists, "### no encontré \(que)")
        XCTAssertLessThanOrEqual(e.frame.maxX, app.frame.width,
                                 "### \(que) se sale por la derecha: \(e.frame) en \(app.frame.width)")
    }

    func revisar(_ marca: String) {
        // Cabeceras de la tabla, que son la columna que se salía.
        for c in ["MONTH", "INCOME", "EXPENSES", "BALANCE"] { dentro(app.staticTexts[c].firstMatch, c) }
        // Y las etiquetas enteras, sin partir ni recortar.
        for b in ["Share", "PDF preview"] {
            let e = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", b)).firstMatch
            dentro(e, b)
            XCTAssertLessThan(e.frame.height, 60, "### \(b) está partido en dos renglones: \(e.frame)")
        }
        parada(marca)
    }

    /// En el iPad pequeño la columna no da ni para lista + detalle, así que el
    /// reporte se empuja y hay que volver para elegir el otro.
    func volverSiHaceFalta() {
        let atras = app.navigationBars.buttons["Reports"].firstMatch
        if atras.exists { atras.tap(); sleep(2) }
    }

    func testEstadoYAnualEnColumnaEstrecha() {
        XCUIDevice.shared.orientation = .portrait; sleep(3)
        let mostrar = app.buttons["Show Sidebar"].firstMatch
        if mostrar.exists { mostrar.tap(); sleep(1) }
        abrirReportes()
        app.staticTexts["Financial statement"].firstMatch
            .coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap(); sleep(3)
        revisar("R-estado-vertical")
        volverSiHaceFalta()
        app.staticTexts["Annual report"].firstMatch
            .coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap(); sleep(3)
        revisar("R-anual-vertical")
    }

    func testEstadoYAnualApaisado() {
        XCUIDevice.shared.orientation = .landscapeLeft; sleep(3)
        abrirReportes()
        app.staticTexts["Financial statement"].firstMatch
            .coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap(); sleep(3)
        revisar("R-estado-apaisado")
        volverSiHaceFalta()
        app.staticTexts["Annual report"].firstMatch
            .coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap(); sleep(3)
        revisar("R-anual-apaisado")
    }
}
