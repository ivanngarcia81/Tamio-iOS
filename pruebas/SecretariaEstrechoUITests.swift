import XCTest

/// Informes de membresía y el panel de Asistencia en una columna estrecha:
/// 13" en vertical con la sidebar (unos 450 pt de contenido).
final class SecretariaEstrecho: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments += ["-prefs.idioma", "ingles", "-AppleLanguages", "(en)"]
        app.launch(); sleep(2)
        XCUIDevice.shared.orientation = .portrait; sleep(3)
        let mostrar = app.buttons["Show Sidebar"].firstMatch
        if mostrar.exists { mostrar.tap(); sleep(1) }
    }

    func parada(_ n: String) { print("MARCA:\(n)"); fflush(stdout); Thread.sleep(forTimeInterval: 3.0) }

    func seccion(_ p: String) {
        let e = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", p)).firstMatch
        XCTAssertTrue(e.waitForExistence(timeout: 5), "### no encontré \(p)")
        e.tap(); sleep(3)
    }

    /// Nada puede quedar fuera del ancho de la ventana.
    func dentro(_ e: XCUIElement, _ que: String) {
        XCTAssertTrue(e.exists, "### no encontré \(que)")
        XCTAssertLessThanOrEqual(e.frame.maxX, app.frame.width,
                                 "### \(que) se sale por la derecha: \(e.frame)")
    }

    func testInformeGeneral() {
        seccion("Membership reports")
        parada("S-informes")
        // La tabla de traslados: o cabe entera, o se dibuja como filas. Lo que
        // no puede es dejar la fecha y el estado fuera de la pantalla.
        for c in ["Rosa Elena Vega", "Daniel Salas Hernández"] { dentro(app.staticTexts[c].firstMatch, c) }
        if app.staticTexts["STATUS"].exists { dentro(app.staticTexts["STATUS"].firstMatch, "STATUS") }
        // Los meses de la gráfica de altas, legibles: a `.caption2` un mes mide
        // unos 20 pt, y encogido al 70 % baja de 16.
        let ene = app.staticTexts["Jan"].firstMatch
        XCTAssertTrue(ene.exists, "### no encontré los meses de la gráfica")
        XCTAssertGreaterThan(ene.frame.height, 12, "### los meses salen encogidos: \(ene.frame)")
        print("### Jan \(ene.frame)")
    }

    func testPanelDeAsistencia() {
        seccion("Membership")
        app.buttons["Attendance"].firstMatch.tap(); sleep(3)
        parada("S-asistencia")
        for r in ["Period average", "Services in period", "Average attendance", "Best service"] {
            let e = app.staticTexts[r].firstMatch
            XCTAssertTrue(e.exists, "### falta el rótulo \(r)")
            XCTAssertLessThan(e.frame.height, 45, "### \(r) salió en más de dos renglones: \(e.frame)")
            print("### \(r) \(e.frame)")
        }
    }
}
