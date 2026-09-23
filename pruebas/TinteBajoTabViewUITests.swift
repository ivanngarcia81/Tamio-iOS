import XCTest

/// **¿Sigue haciendo falta destintar las cápsulas no elegidas?**
///
/// La regla de la casa dice que `.buttonStyle(.glass)` hereda el tinte del
/// `TabView`, y que por eso las no elegidas hay que bajarlas a
/// `.tint(Color.primary)` o salen todas en verde y todas parecen activas. Se
/// midió y se escribió en septiembre de 2026, **sobre iOS 26**.
///
/// Medido de nuevo el 16-sep en el iPad con iOS 27, sobre los selectores de
/// Ingresos y Depósitos: con destinte y sin él, los píxeles salen IDÉNTICOS.
/// Pero esa columna cuelga de una barra lateral, no de un `TabView`, así que la
/// medida no distingue dos explicaciones:
///
/// 1. no hay tinte que heredar porque no hay `TabView`; o
/// 2. iOS 27 cambió `.glass` y la regla está caducada en toda la app.
///
/// Esta prueba va al único sitio donde se pueden separar: el selector de vista
/// de Agenda **en el teléfono**, que sí vive dentro del `TabView`. No afirma
/// nada por sí sola: se para en las `MARCA:` para que el shell capture, y el
/// número lo pone `pruebas/contraste.py` sobre el PNG, con el `.tint` puesto y
/// quitado.
final class TinteBajoTabViewUITests: XCTestCase {
    /// **Solo iPhone**: mide el tinte bajo el `TabView` del teléfono; ella misma
    /// lo dice al fallar. En el iPad físico (23-sep) daba roja con «No matches
    /// found for Descendants matching type TabBar» o su equivalente, que no dice
    /// nada de la app: es la omisión de las de iPad, al revés.
    override func setUpWithError() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "solo iPhone")
    }

    func testSelectorDeAgenda() {
        let app = XCUIApplication()
        app.launchArguments = ["-prefs.bienvenidaVista", "1",
                               "-prefs.idioma", "ingles", "-AppleLanguages", "(en)",
                               "-prefs.tema", "oscuro"]
        // Candado apagado por argumento: un bloqueo guardado en el aparato
        // la dejaría tapada (ver LEEME.md, «El candado y las corridas»).
        app.launchArguments += ["-bloqueo.biometrico", "NO"]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 20))
        sleep(2)

        XCTAssertTrue(app.tabBars.buttons["Secretary"].waitForExistence(timeout: 20),
                      "no hay barra de pestañas: esta prueba solo vale en el teléfono")
        app.tabBars.buttons["Secretary"].tap()
        sleep(2)

        // El hub de Secretaría puede pedir scroll, y los rótulos llevan el
        // subtítulo detrás ("Membership, ..."), así que se busca por prefijo y
        // se vuelca lo que hay si no aparece: un "no existe" a secas manda a
        // buscar el fallo donde no está.
        let calendario = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'Calendar'")).firstMatch
        for _ in 0..<5 {
            if calendario.exists && calendario.isHittable { break }
            app.swipeUp(velocity: .slow); sleep(1)
        }
        if !calendario.waitForExistence(timeout: 6) {
            print("HUB:" + app.buttons.allElementsBoundByIndex.prefix(30)
                    .map { String($0.label.prefix(28)) }.joined(separator: "|"))
            fflush(stdout)
            XCTFail("no está la fila «Calendar»")
            return
        }
        calendario.tap()
        sleep(3)

        // Las tres cápsulas del selector de vista. "Month" viene elegida.
        XCTAssertTrue(app.buttons["Month"].waitForExistence(timeout: 8),
                      "el selector de Agenda ya no tiene una cápsula «Month»")
        print("MARCA:agenda-tabview")
        fflush(stdout)
        Thread.sleep(forTimeInterval: 3.5)

        // Se deja dicho lo que la vista SÍ sabe, para separarlo de lo que solo
        // dice el píxel: el rasgo de selección.
        print("RASGOS:Month=\(app.buttons["Month"].isSelected)" +
              "|Week=\(app.buttons["Week"].isSelected)" +
              "|List=\(app.buttons["List"].isSelected)")
        fflush(stdout)
    }
}
