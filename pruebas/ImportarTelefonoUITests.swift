import XCTest

/// El teléfono comparte `MiembrosView`, así que el arreglo tiene que valer
/// aquí también: menú → selector → CSV → mapeo → previa.
final class ImportarTelefono: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments += ["-prefs.idioma", "ingles", "-AppleLanguages", "(en)",
                                "-prefs.bienvenidaVista", "YES"]
        app.launch(); sleep(3)
    }

    private func aportantes() {
        app.tabBars.buttons["Treasury"].tap(); sleep(2)
        let fila = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Contributors'")).firstMatch
        for _ in 0..<4 where !fila.isHittable { app.swipeUp(velocity: .slow); sleep(1) }
        fila.tap(); sleep(3)
    }

    private func selectorAbierto() -> Bool {
        let sb = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        return ["Recents", "On My iPhone", "iCloud Drive"].contains {
            app.staticTexts[$0].exists || sb.staticTexts[$0].exists
        }
    }

    /// Elige `archivo` en el selector y devuelve si llegó al mapeo.
    private func toque(_ dx: CGFloat, _ dy: CGFloat) {
        app.coordinate(withNormalizedOffset: CGVector(dx: dx, dy: dy)).tap()
    }

    /// El selector del teléfono es de otro proceso y sus elementos no se dejan
    /// consultar; además recuerda entre corridas dónde estaba. Lo único fijo es
    /// el buscador de arriba, así que el archivo se busca por su nombre.
    private func elegir(_ archivo: String) -> Bool {
        toque(0.5, 0.176); sleep(1)           // el campo de búsqueda
        app.typeText(archivo)
        sleep(3)
        toque(0.176, 0.398); sleep(4)         // el primer resultado de la rejilla
        return app.buttons["Continue"].firstMatch.waitForExistence(timeout: 6)
    }

    private func importar(_ opcion: String, archivo: String, marca: String) {
        aportantes()
        let menu = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'File'")).firstMatch
        XCTAssertTrue(menu.waitForExistence(timeout: 5), "no encontré el menú Archivo")
        menu.tap(); sleep(1)
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", opcion)).firstMatch.tap()
        sleep(3)
        XCTAssertTrue(selectorAbierto(), "el selector de archivos no abrió")
        XCTAssertTrue(elegir(archivo), "elegir el CSV no llevó al mapeo de columnas")
        print("### \(opcion) · botones=" + app.buttons.allElementsBoundByIndex.prefix(8)
              .filter { !$0.label.isEmpty }.map(\.label).joined(separator: " | "))
        XCTAssertTrue(app.buttons["Continue"].firstMatch.waitForExistence(timeout: 5),
                      "el CSV no llegó al mapeo de columnas")
        app.buttons["Continue"].firstMatch.tap(); sleep(4)
        print("### tras Continue · botones=" + app.buttons.allElementsBoundByIndex.prefix(8)
              .filter { !$0.label.isEmpty }.map(\.label).joined(separator: " | "))
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Import '")).firstMatch.exists,
                      "el mapeo no llevó a la previa de importación")
        print("MARCA:\(marca)"); fflush(stdout); Thread.sleep(forTimeInterval: 2)
    }

    func testAportantes() { importar("Import givers", archivo: "givers-template", marca: "IT-01-aportantes") }
    func testAportes() { importar("Import gifts", archivo: "gifts-template", marca: "IT-02-aportes") }
}
