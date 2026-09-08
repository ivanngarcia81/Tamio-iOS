import XCTest

/// **El recorrido de bienvenida, con la app sin sesión.**
///
/// Se queda quieta en cada paso para que el shell dispare la captura. El modo
/// revisión NO sirve aquí: entra solo, y lo que se quiere ver es justo la
/// pantalla de antes de entrar.
final class BienvenidaUITests: XCTestCase {

    private func recorrer(idioma: String, region: String) {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(\(idioma))", "-AppleLocale", region]
        app.launch()
        sleep(8)
        for _ in 0..<4 {
            sleep(7)
            let siguiente = app.buttons["Siguiente"].firstMatch
            let next = app.buttons["Next"].firstMatch
            let comenzar = app.buttons["Comenzar"].firstMatch
            let empezar = app.buttons["Get started"].firstMatch
            for b in [siguiente, next, comenzar, empezar] where b.exists {
                b.tap(); break
            }
        }
        sleep(8)
    }

    func test1EnEspanol() { recorrer(idioma: "es-MX", region: "es_MX") }
    func test2EnIngles()  { recorrer(idioma: "en-US", region: "en_US") }
}
