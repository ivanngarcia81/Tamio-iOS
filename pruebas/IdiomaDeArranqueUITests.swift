import XCTest

/// **Con qué idioma arranca la app, sin elegir nada en Preferencias.**
///
/// El inglés es el idioma principal y el español el secundario, así que la
/// pregunta no es cuál gana por omisión: es si "Automático" cumple lo que su
/// propio rótulo promete, "el idioma del sistema operativo".
///
/// No lo cumplía. `Locale.current` devuelve el idioma en el que iOS resolvió
/// ESTA app —inglés, que es su región de desarrollo—, no el del aparato, así
/// que un iPhone entero en español abría Tamio en inglés.
///
/// **Las dos corridas hacen falta.** La de español sola no prueba nada: una
/// app que estuviera en español SIEMPRE la pasaría igual.
final class IdiomaDeArranqueUITests: XCTestCase {

    private func barra(idioma: String, region: String) -> (esp: Bool, ing: Bool) {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(\(idioma))", "-AppleLocale", region]
        app.launch()
        sleep(10)
        return (app.buttons["Inicio"].exists || app.staticTexts["Inicio"].exists,
                app.buttons["Home"].exists   || app.staticTexts["Home"].exists)
    }

    func testUnTelefonoEnEspanolAbreEnEspanol() {
        let r = barra(idioma: "es-MX", region: "es_MX")
        XCTAssertTrue(r.esp, "### teléfono en español y la app abrió en inglés")
        XCTAssertFalse(r.ing)
    }

    func testUnTelefonoEnInglesSigueAbriendoEnIngles() {
        let r = barra(idioma: "en-US", region: "en_US")
        XCTAssertTrue(r.ing, "### teléfono en inglés y la app no abrió en inglés")
        XCTAssertFalse(r.esp)
    }

    /// Un idioma que la app no habla cae en el principal.
    func testUnTelefonoEnFrancesCaeEnIngles() {
        let r = barra(idioma: "fr-FR", region: "fr_FR")
        XCTAssertTrue(r.ing, "### el francés no cayó en el idioma principal")
        XCTAssertFalse(r.esp)
    }
}
