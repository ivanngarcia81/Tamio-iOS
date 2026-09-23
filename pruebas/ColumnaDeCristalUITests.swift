import XCTest

/// **Los dos segmentados que quedaban dentro de una `safeAreaBar`: Ingresos y
/// Depósitos, en la columna del iPad.**
///
/// `c0804af` dio por cerrado este caso con Membresía y Aportantes, y quedaban
/// estos dos. No salían en ninguna captura del teléfono porque su cabecera va
/// dentro de un `if !compacto`: **solo se dibujan en iPad**, y por eso esta
/// prueba solo tiene sentido ahí.
///
/// Lo que mira, y que la vista sola no dice: que **solo una** cápsula tenga el
/// rasgo de seleccionada.
///
/// **No cubre el color.** Se comprobó el 16-sep-2026 quitando el
/// `.tint(Color.primary)` de la no elegida: la prueba siguió en verde, porque
/// `isSelected` lo pone `.accessibilityAddTraits` en la otra rama. Para el
/// color hay que medir el píxel con `pruebas/contraste.py`. Una prueba que no
/// ha fallado nunca no protege nada, y esta protege el rasgo, no el tinte.
///
/// El segmentado del TELÉFONO no se toca y no se prueba aquí: vive en
/// `ToolbarItem(placement: .title)`, donde el sistema ya pone la cápsula.
final class ColumnaDeCristalUITests: XCTestCase {
    /// **Solo iPad.** Pide barra lateral o apaisado, y el iPhone no tiene
    /// ninguna de las dos (`project.yml`: solo vertical; `RootView`: la barra
    /// lateral solo con `.regular`). Corrida en el teléfono daba rojas que no
    /// decían nada de la app: ver `docs/ROJAS-SEPTIEMBRE.md`.
    override func setUpWithError() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "solo iPad")
    }

    var app: XCUIApplication!

    /// El tema se pone por la preferencia de la APP, no con el del sistema: la
    /// app fija `preferredColorScheme` desde `prefs.tema` y mientras esté en
    /// "claro" u "oscuro" ignora al aparato. Y va como argumento de lanzamiento
    /// en cada prueba, que `ProcessInfo.environment` dentro del test es el del
    /// runner y `xcodebuild` no reenvía las variables. Las dos cosas están
    /// escritas en `CategoriasDeCristalUITests`, que las pagó.
    func arrancar(tema: String) {
        continueAfterFailure = true
        // **Apaisado, y desde XCUITest**: el simulador no gira desde el shell,
        // y estos controles viven en la columna, que en vertical y estrecho ni
        // siquiera se ve. Es lo que ya hace `RecorridoIPadUITests`.
        XCUIDevice.shared.orientation = .landscapeLeft
        app = XCUIApplication()
        // `bienvenidaVista` porque en un simulador recién hecho la app abre en
        // la bienvenida y la prueba se queda mirando el carrusel: costó una
        // corrida entera de 120 s con cuatro fallos que no eran del control.
        app.launchArguments += ["-prefs.bienvenidaVista", "1",
                                "-prefs.idioma", "ingles", "-AppleLanguages", "(en)",
                                "-prefs.tema", tema]
        // Candado apagado por argumento: un bloqueo guardado en el aparato
        // la dejaría tapada (ver LEEME.md, «El candado y las corridas»).
        app.launchArguments += ["-bloqueo.biometrico", "NO"]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 20))
        sleep(3)
    }

    /// Abre la barra lateral si viene plegada, como en el recorrido del iPad.
    func abrirSidebarSiHaceFalta() {
        let boton = app.buttons.matching(NSPredicate(
            format: "label CONTAINS 'Sidebar' OR label CONTAINS 'barra lateral'")).firstMatch
        if boton.exists && boton.isHittable {
            let yaSeVe = app.buttons.matching(NSPredicate(
                format: "label BEGINSWITH 'Reports' OR label BEGINSWITH 'Reportes'")).firstMatch
            if !yaSeVe.exists || !yaSeVe.isHittable { boton.tap(); sleep(1) }
        }
    }

    func parada(_ n: String) { print("MARCA:\(n)"); fflush(stdout); Thread.sleep(forTimeInterval: 3.2) }

    func marcada(_ nombre: String) -> Bool { app.buttons[nombre].isSelected }

    /// Abre una sección desde la barra lateral del iPad. Se busca por prefijo
    /// porque la fila lleva el contador detrás del nombre.
    func abrir(_ seccion: String) {
        abrirSidebarSiHaceFalta()
        let p = NSPredicate(format: "label BEGINSWITH %@", seccion)
        let fila = app.buttons.matching(p).firstMatch
        if !fila.waitForExistence(timeout: 20) {
            // Si no está, decir QUÉ hay: un "no existe" a secas manda a buscar
            // el fallo en el control cuando lo que pasa es que la app abrió en
            // otra pantalla.
            print("BARRA-LATERAL:" + app.buttons.allElementsBoundByIndex.prefix(25).map(\.label).joined(separator: "|"))
            XCTFail("no está la fila «\(seccion)» en la barra lateral")
            return
        }
        fila.tap()
        sleep(3)
    }

    // MARK: - Ingresos / Gastos

    func testIngresosEnClaro()  { ingresos(tema: "claro") }
    func testIngresosEnOscuro() { ingresos(tema: "oscuro") }

    func ingresos(tema: String) {
        arrancar(tema: tema)
        abrir("Income")

        // **Por identificador y no por rótulo.** La fila de la barra lateral se
        // llama "Income" igual que la cápsula, y buscar por rótulo encontraba
        // las dos: "Multiple matching elements found". Depósitos no lo necesita
        // —"Pending" no se repite— pero se trata igual por claridad.
        let ingresos = app.buttons["capsulaTipoIngreso"]
        let gastos   = app.buttons["capsulaTipoGasto"]

        XCTAssertTrue(ingresos.waitForExistence(timeout: 8),
                      "la columna ya no tiene una cápsula de Ingresos: ¿volvió el Picker?")
        parada("ingresos-\(tema)-ingresos")

        // Las dos condiciones importan: solo la primera pasaría también con las
        // dos cápsulas teñidas de verde, que es justo el fallo que se corrige.
        XCTAssertTrue(ingresos.isSelected, "Ingresos no sale marcado al abrir")
        XCTAssertFalse(gastos.isSelected,
                       "Gastos también sale marcado: falta destintar la no elegida con .tint(.primary)")

        gastos.tap(); sleep(2)
        parada("ingresos-\(tema)-gastos")
        XCTAssertTrue(gastos.isSelected, "tocar Gastos no lo marca")
        XCTAssertFalse(ingresos.isSelected, "Ingresos sigue marcado tras tocar Gastos")
    }

    // MARK: - Depósitos

    func testDepositosEnClaro()  { depositos(tema: "claro") }
    func testDepositosEnOscuro() { depositos(tema: "oscuro") }

    func depositos(tema: String) {
        arrancar(tema: tema)
        abrir("Deposits")

        XCTAssertTrue(app.buttons["Pending"].waitForExistence(timeout: 8),
                      "la columna ya no tiene una cápsula «Pending»: ¿volvió el Picker?")
        parada("depositos-\(tema)-pendientes")

        XCTAssertTrue(marcada("Pending"), "Pendientes no sale marcado al abrir")
        XCTAssertFalse(marcada("Deposited"),
                       "Depositados también sale marcado: falta destintar la no elegida")

        app.buttons["Deposited"].tap(); sleep(2)
        parada("depositos-\(tema)-depositados")
        XCTAssertTrue(marcada("Deposited"), "tocar Depositados no lo marca")
        XCTAssertFalse(marcada("Pending"), "Pendientes sigue marcado tras tocar Depositados")
    }
}
