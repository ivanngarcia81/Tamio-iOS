import XCTest

/// Volcado mínimo de la primera pantalla: para saber QUÉ hay delante cuando una
/// navegación falla, en vez de adivinarlo. No afirma nada.
final class VolcadoRapidoUITests: XCTestCase {
    func testQueHayEnPantalla() {
        let app = XCUIApplication()
        app.launchArguments += ["-prefs.idioma", "ingles", "-AppleLanguages", "(en)"]
        app.launch(); sleep(5)
        func lista(_ q: XCUIElementQuery, _ n: String) {
            let s = q.allElementsBoundByIndex.prefix(30)
                .filter { !$0.label.isEmpty }
                .map { "\($0.label)\($0.isHittable ? "" : "·NOHIT")" }
                .joined(separator: " | ")
            print("### \(n): \(s)")
        }
        lista(app.staticTexts, "TEXTOS")
        lista(app.buttons, "BOTONES")
        print("### ALERTAS: \(app.alerts.allElementsBoundByIndex.map(\.label).joined(separator: " | "))")
        fflush(stdout)
    }
}
