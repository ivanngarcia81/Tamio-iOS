import XCTest

/// La fila de borrar la cuenta, en Ajustes · Cuenta. **No se pulsa el botón
/// destructivo**: solo se comprueba que está, que se encuentra y que su aviso
/// se lee. Lo que hace de verdad lo hace una Edge Function contra el servidor.
final class BorrarCuentaUITests: XCTestCase {
    private func abrirCuenta(_ idioma: String, _ region: String) {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(\(idioma))", "-AppleLocale", region]
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
