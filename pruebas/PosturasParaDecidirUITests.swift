import XCTest

/// **Las dos posturas que hay que MIRAR para decidir, no arreglar.**
///
/// No afirma nada: navega, desplaza el contenido —que es la única postura donde
/// se nota— y se para en una `MARCA:` para que el shell capture con
/// `xcrun simctl io <udid> screenshot`. La decisión es de Iván.
///
/// **A · el fondo del tab bar** (`RootView`, `.toolbarBackground(.bar/.visible,
/// for: .tabBar)`). Viene del PR 2 (`cdd267d`), anterior a Liquid Glass, cuando
/// se cambió `.ultraThinMaterial` por `.bar` porque el material más transparente
/// del sistema dejaba LEER el contenido por debajo de la barra. Con el cristal
/// de iOS 26/27 puede que ya no haga falta. El criterio a comprobar está escrito
/// en `docs/VERIFICACION-PR1-9.md`: **«ningún texto de contenido se lee a través
/// del tab bar»**, y solo se puede juzgar con la lista desplazada, con filas
/// pasando por detrás.
///
/// **B · las cabeceras de día del Registro** (`RegistroView.encabezadoDia`).
/// Se fijan con `pinnedViews` y llevan `.regularMaterial`, así que al desplazar
/// quedan pegadas bajo la barra de navegación: material opaco contra cristal,
/// que es el patrón que esta pasada viene quitando.
final class PosturasParaDecidirUITests: XCTestCase {

    var app: XCUIApplication!

    func arrancar(tema: String) {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments = ["-prefs.bienvenidaVista", "1",
                               "-prefs.idioma", "ingles", "-AppleLanguages", "(en)",
                               "-prefs.tema", tema]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 20))
        sleep(2)
    }

    func parada(_ n: String) { print("MARCA:\(n)"); fflush(stdout); Thread.sleep(forTimeInterval: 3.5) }

    /// Busca una fila por prefijo, desplazando si hace falta, y vuelca lo que
    /// hay si no aparece. Los hubs del teléfono piden scroll y los rótulos
    /// llevan el subtítulo detrás: sin esto, un "no existe" manda a buscar el
    /// fallo donde no está. Costó tres corridas aprenderlo.
    @discardableResult
    func tocarFila(_ prefijo: String) -> Bool {
        let e = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", prefijo)).firstMatch
        for _ in 0..<6 {
            if e.exists && e.isHittable { e.tap(); sleep(3); return true }
            app.swipeUp(velocity: .slow); sleep(1)
        }
        print("NO-ESTA \(prefijo) · hay:" + app.buttons.allElementsBoundByIndex.prefix(30)
                .map { String($0.label.prefix(24)) }.joined(separator: "|"))
        fflush(stdout)
        XCTFail("no está la fila «\(prefijo)»")
        return false
    }

    // MARK: - A · el tab bar con contenido por detrás

    func testAFondoDelTabBarOscuro() { fondoTabBar(tema: "oscuro") }
    func testAFondoDelTabBarClaro()  { fondoTabBar(tema: "claro") }

    func fondoTabBar(tema: String) {
        arrancar(tema: tema)
        XCTAssertTrue(app.tabBars.buttons["Treasury"].waitForExistence(timeout: 20))
        app.tabBars.buttons["Treasury"].tap(); sleep(2)
        // «Transactions», no «Income»: en el hub del teléfono la fila reúne
        // ingresos y gastos y se llama "Transactions, 28 records". En la barra
        // lateral del iPad sí son dos filas. Lo dijo el volcado.
        guard tocarFila("Transactions") else { return }

        parada("A-tabbar-\(tema)-sin-desplazar")

        // **Desplazada es la única postura que vale.** Sin filas pasando por
        // detrás, con fondo y sin fondo se ven casi iguales.
        for _ in 0..<3 { app.swipeUp(velocity: .slow); sleep(1) }
        parada("A-tabbar-\(tema)-desplazada")
    }

    // MARK: - B · las cabeceras fijadas del Registro

    func testBCabecerasDelRegistroOscuro() { cabecerasRegistro(tema: "oscuro") }
    func testBCabecerasDelRegistroClaro()  { cabecerasRegistro(tema: "claro") }

    func cabecerasRegistro(tema: String) {
        arrancar(tema: tema)
        XCTAssertTrue(app.tabBars.buttons["Secretary"].waitForExistence(timeout: 20))
        app.tabBars.buttons["Secretary"].tap(); sleep(2)
        guard tocarFila("Log") else { return }

        parada("B-registro-\(tema)-sin-desplazar")

        // Con el scroll, la cabecera de día se pega bajo la barra: es ahí donde
        // el material opaco se ve contra el cristal.
        for _ in 0..<3 { app.swipeUp(velocity: .slow); sleep(1) }
        parada("B-registro-\(tema)-desplazada")
    }
}
