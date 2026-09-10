import XCTest

/// **Cuenta las cápsulas de la barra en las cuatro pantallas de lista.**
///
/// El sistema descarta en silencio lo que no le cabe en la barra: así se quedó
/// Ingresos **sin botón de crear** (§2.3 de `docs/CONTEXTO.md`), sin un error ni
/// un aviso. El buscador nativo gasta cápsula, y en inglés las etiquetas son más
/// largas. Esta prueba vuelca la barra de cada pantalla y la compara con lo que
/// esa pantalla dice tener.
///
/// Se corre dos veces sin tocar el código, con el tamaño de fábrica y con AX1:
///     xcrun simctl ui <udid> content_size large
///     xcrun simctl ui <udid> content_size accessibility-medium
final class CapsulasDeBarra: XCTestCase {

    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments += ["-prefs.idioma", "ingles", "-AppleLanguages", "(en)"]
        app.launch(); sleep(2)
    }

    func pestana(_ n: String) { app.tabBars.buttons[n].tap(); sleep(2) }

    @discardableResult
    func abrirFila(_ prefijo: String) -> Bool {
        let p = NSPredicate(format: "label BEGINSWITH %@", prefijo)
        for intento in 0..<6 {
            let e = app.buttons.matching(p).firstMatch
            if e.waitForExistence(timeout: intento == 0 ? 4 : 1) && e.isHittable { e.tap(); sleep(2); return true }
            app.swipeUp(velocity: .slow); sleep(1)
        }
        return false
    }

    func volver() {
        let a = app.navigationBars.buttons.element(boundBy: 0)
        if a.exists && a.isHittable { a.tap(); sleep(2) }
    }

    func barra(_ pantalla: String, esperados: [String]) {
        let items = app.navigationBars.buttons.allElementsBoundByIndex
        let etiquetas = items.map { $0.label.isEmpty ? "«sin rótulo»" : $0.label }
        let campos = app.navigationBars.searchFields.count + app.searchFields.count
        print("BARRA \(pantalla): n=\(items.count) buscadores=\(campos) → " + etiquetas.joined(separator: " ‖ "))
        for e in esperados where !etiquetas.contains(where: { $0.hasPrefix(e) }) {
            print("  FALTA en \(pantalla): \(e)")
            XCTFail("\(pantalla): falta «\(e)» en la barra")
        }
        fflush(stdout)
    }

    func testLasCuatroListas() {
        pestana("Treasury")
        if abrirFila("Transactions") {
            barra("Movimientos", esperados: ["Period and filters", "New", "Income", "Expenses"])
            volver()
        }
        if abrirFila("Contributors") {
            barra("Aportantes", esperados: ["New"])
            volver()
        }
        if abrirFila("Deposits") {
            barra("Depósitos", esperados: ["Sort", "New", "Pending", "Deposited"])
            volver()
        }
        pestana("Secretary")
        if abrirFila("Membership,") {
            barra("Membresía", esperados: ["Members", "More filters", "New"])
            volver()
        }
    }
}
