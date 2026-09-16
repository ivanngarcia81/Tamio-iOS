import XCTest

/// **El único caso que quedó sin medir al quitarle el fondo al tab bar.**
///
/// `7b34c3f` quitó `.toolbarBackground(.bar, for: .tabBar)` + `.visible` con una
/// medida delante: `pixdiff` daba 0.000% en cuatro posturas. Pero todas eran con
/// la lista EN REPOSO, y ahí el contenido nunca queda detrás de la barra porque
/// `colchonInferior()` mete un inset. Quedó dicho en ese commit que el instante
/// del arrastre —cuando la lista rebota y algo sí pasa por detrás— no se había
/// medido, y que el riesgo se asumía a sabiendas.
///
/// Esto lo mide. El truco es el orden: se imprime la `MARCA:` **antes** de
/// empezar el arrastre y se arrastra SOSTENIENDO el dedo varios segundos, de
/// modo que el capturador de fuera —que mira el log cada segundo— dispare
/// mientras la lista está desplazada y el dedo sigue puesto. Capturar después
/// del gesto no sirve: la lista ya volvió a su sitio.
final class TabBarDuranteElArrastreUITests: XCTestCase {

    func testContenidoDetrasDelTabBar() {
        let app = XCUIApplication()
        app.launchArguments = ["-prefs.bienvenidaVista", "1",
                               "-prefs.idioma", "ingles", "-AppleLanguages", "(en)",
                               "-prefs.tema", ProcessInfo.processInfo.environment["TEMA"] ?? "claro"]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 25))
        sleep(2)

        XCTAssertTrue(app.tabBars.buttons["Treasury"].waitForExistence(timeout: 20))
        app.tabBars.buttons["Treasury"].tap(); sleep(2)

        let fila = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Transactions'")).firstMatch
        for _ in 0..<6 {
            if fila.exists && fila.isHittable { break }
            app.swipeUp(velocity: .slow); sleep(1)
        }
        guard fila.waitForExistence(timeout: 8) else {
            print("HUB:" + app.buttons.allElementsBoundByIndex.prefix(25)
                    .map { String($0.label.prefix(24)) }.joined(separator: "|"))
            fflush(stdout)
            XCTFail("no está «Transactions»"); return
        }
        fila.tap(); sleep(3)

        // Bajar un poco para tener filas por encima y por debajo.
        app.swipeUp(velocity: .slow); sleep(2)

        // **La marca va ANTES del gesto**, que es lo que hace que la captura
        // caiga con el dedo puesto y la lista desplazada.
        print("MARCA:arrastre-\(ProcessInfo.processInfo.environment["TEMA"] ?? "claro")")
        fflush(stdout)

        let abajo  = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.80))
        let arriba = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.30))
        abajo.press(forDuration: 0.1,
                    thenDragTo: arriba,
                    withVelocity: .slow,
                    thenHoldForDuration: 5.0)
        sleep(1)
    }
}
