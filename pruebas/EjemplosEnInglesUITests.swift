import XCTest

/// **Los ejemplos de los campos de Ajustes, con la app en inglés.**
///
/// Una prueba por pantalla, cada una desde cero: el botón de volver de esta app
/// no vive en `navigationBars` —es el chevron redondo de `NavHeader`— y
/// buscarlo ahí no devuelve nada. Relanzar sale más barato que perseguirlo.
///
/// No afirman nada por sí solas: lo que se comprueba es la foto —que ningún
/// ejemplo gris quede en español—, que es justo lo que el compilador no ve. El
/// shell dispara `simctl io … screenshot` durante los catorce segundos quietos.
final class EjemplosEnInglesUITests: XCTestCase {

    private func abrirAjustes() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-prefs.idioma", "ingles"]
        app.launch()
        sleep(8)
        app.buttons["Settings"].firstMatch.tap()
        sleep(4)
        return app
    }

    /// "Church" es además el título de su sección, así que el rótulo no basta:
    /// la cabecera de sección NO vive dentro de una celda y la fila sí, que es
    /// lo que las separa.
    func test1Iglesia() {
        let app = abrirAjustes()
        let fila = app.cells.containing(.staticText, identifier: "Church").firstMatch
        XCTAssertTrue(fila.waitForExistence(timeout: 10), "### no hay fila de Iglesia")
        fila.tap()
        sleep(14)
    }

    func test2Institucion() {
        let app = abrirAjustes()
        let fila = app.staticTexts["Institution"].firstMatch
        XCTAssertTrue(fila.waitForExistence(timeout: 10), "### no hay fila de Institución")
        fila.tap()
        sleep(14)
    }

    func test4Acceso() {
        let app = abrirAjustes()
        let fila = app.staticTexts["Access & areas"].firstMatch
        XCTAssertTrue(fila.waitForExistence(timeout: 10), "### no hay fila de Acceso")
        fila.tap()
        sleep(6)
        app.swipeUp(); app.swipeUp()
        sleep(12)
    }

    func test3Tesorero() {
        let app = abrirAjustes()
        let fila = app.staticTexts["Treasurer & pastor"].firstMatch
        XCTAssertTrue(fila.waitForExistence(timeout: 10), "### no hay fila de Tesorero")
        fila.tap()
        sleep(14)
    }
}
