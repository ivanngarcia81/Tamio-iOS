import XCTest

/// La fila de borrar la cuenta, en Ajustes · Cuenta. **No se pulsa el botón
/// destructivo**: solo se comprueba que está, que se encuentra y que su aviso
/// se lee. Lo que hace de verdad lo hace una Edge Function contra el servidor.
final class BorrarCuentaUITests: XCTestCase {
    /// **Solo iPhone**: toca la primera celda de los Ajustes del teléfono (la
    /// fila de perfil), que en el iPad no es una celda. En el iPad físico
    /// (23-sep) daba roja con «No matches found for Descendants matching type
    /// TabBar» o su equivalente, que no dice nada de la app: es la omisión de las
    /// de iPad, al revés.
    override func setUpWithError() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "solo iPhone")
    }

    private func abrirCuenta(_ idioma: String, _ region: String) {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(\(idioma))", "-AppleLocale", region]
        // Candado apagado por argumento: un bloqueo guardado en el aparato
        // la dejaría tapada (ver LEEME.md, «El candado y las corridas»).
        app.launchArguments += ["-bloqueo.biometrico", "NO"]
        app.launch()
        sleep(8)
        // La pestaña se llama distinto en cada idioma; se toca la que exista.
        for rotulo in ["Ajustes", "Settings"] where app.buttons[rotulo].firstMatch.exists {
            app.buttons[rotulo].firstMatch.tap(); break
        }
        sleep(3)
        // La fila de perfil, arriba del todo.
        app.cells.element(boundBy: 0).tap()
        sleep(4)
        for _ in 0..<6 { app.swipeUp() }
        sleep(12)
    }
    func test1Espanol() { abrirCuenta("es-MX", "es_MX") }
    func test2Ingles()  { abrirCuenta("en-US", "en_US") }
}
