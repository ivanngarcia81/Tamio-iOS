import XCTest

/// **La app en una ventana estrecha de iPadOS 26.**
///
/// El iPad de este proyecto conserva las cuatro orientaciones y no declara
/// `UIRequiresFullScreen`, así que la ventana puede estrecharse hasta que la
/// app cae a clase de tamaño **compacta** y dibuja su forma de teléfono dentro
/// del iPad. Es la postura de Split View, Slide Over y las ventanas de
/// iPadOS 26, y lo que hay que comprobar es que el cambio de clase en caliente
/// no se lleva por delante lo que había en pantalla.
///
/// **Cómo se estrecha la ventana**, que es lo que costó encontrar: el asa de la
/// esquina inferior derecha **de la ventana** (no de la pantalla), con una
/// pulsación LARGA antes de arrastrar y otra al soltar. Con `press(forDuration:
/// 0.6)` no agarra; con 1.0 sí. El teclado no vale: ni globo+flecha ni
/// control+globo+flecha mueven nada desde XCUITest.
final class MultitareaIPad: XCTestCase {
    var app: XCUIApplication!
    let sb = XCUIApplication(bundleIdentifier: "com.apple.springboard")

    override func setUp() {
        continueAfterFailure = true
        app = XCUIApplication()
        // `-prefs.bienvenidaVista` salta el recorrido de bienvenida: es un
        // valor volátil de `UserDefaults`, así que la prueba no depende de
        // que el contenedor del simulador ya lo tenga puesto. Sin él, un
        // contenedor recién estrenado abre la app en la bienvenida y no hay
        // ni sidebar ni pestañas.
        app.launchArguments += ["-prefs.idioma", "ingles", "-AppleLanguages", "(en)",
                                "-prefs.bienvenidaVista", "YES"]
        app.launch(); sleep(2)
        XCUIDevice.shared.orientation = .landscapeLeft; sleep(3)
        // **La ventana se queda como la dejó la prueba anterior.** No es
        // estado de la app: es de la ventana, y sobrevive a relanzarla. Sin
        // esto, la segunda prueba de la tanda arranca en compacto y no
        // encuentra ni la sidebar ni las secciones.
        print("### al arrancar: \(Int(app.frame.width))x\(Int(app.frame.height)) tab=\(app.tabBars.firstMatch.exists)")
        if app.frame.width < 1000 { pantallaCompleta() }
    }

    override func tearDown() {
        pantallaCompleta()  // devolver la ventana antes de irse
        XCUIDevice.shared.orientation = .portrait; sleep(1)
    }

    func parada(_ n: String) { print("MARCA:\(n)"); fflush(stdout); Thread.sleep(forTimeInterval: 3.0) }

    /// Arrastra el asa de la ventana hasta esa fracción de la pantalla.
    ///
    /// **Reintenta**: el agarre falla una de cada dos o tres veces —el teclado
    /// del sistema, una hoja recién presentada o el propio temporizado—, y una
    /// prueba que siga adelante con la ventana sin estrechar no mide nada.
    @discardableResult
    func ancho(_ fraccion: CGFloat) -> CGFloat {
        let objetivo = sb.frame.width * fraccion
        for intento in 1...3 {
            let esquina = app.coordinate(withNormalizedOffset: CGVector(dx: 1.0, dy: 1.0))
            let destino = sb.coordinate(withNormalizedOffset: CGVector(dx: fraccion, dy: 0.98))
            esquina.press(forDuration: 1.0, thenDragTo: destino, withVelocity: .slow,
                          thenHoldForDuration: 1.0)
            sleep(3)
            if abs(app.frame.width - objetivo) < 250 { return app.frame.width }
            print("### intento \(intento) de estrechar: \(Int(app.frame.width)) pt")
        }
        return app.frame.width
    }

    /// **Devolver la ventana a pantalla completa NO se hace arrastrando.**
    /// Medido: el asa de la esquina estrecha bien pero no ensancha —de 375 pt
    /// no sube ni al segundo intento—. Lo que sí, el botón "Zoom" de los
    /// controles de ventana, que vive en SpringBoard.
    func pantallaCompleta() {
        guard app.frame.width < 1000 else { return }
        let ctrl = sb.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Window Controls'")).firstMatch
        if ctrl.waitForExistence(timeout: 5) {
            ctrl.tap(); sleep(2)
            if sb.buttons["Zoom"].exists { sb.buttons["Zoom"].tap(); sleep(3) }
        }
        print("### pantalla completa: \(Int(app.frame.width))")
    }

    var esCompacta: Bool { app.tabBars.firstMatch.exists }

    func seccion(_ p: String) {
        let e = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", p)).firstMatch
        if !(e.exists && e.isHittable) {
            app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'sidebar'")).firstMatch.tap()
            sleep(1)
        }
        XCTAssertTrue(e.waitForExistence(timeout: 5), "### no encontré \(p)")
        e.tap(); sleep(2)
    }

    /// La app cambia de forma con la ventana, y el detalle abierto sobrevive.
    func testElDetalleSobreviveAlCambioDeClase() {
        seccion("Income")
        app.staticTexts["Mission offering"].firstMatch
            .coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap(); sleep(2)
        XCTAssertTrue(app.staticTexts["AUDIT TRAIL"].waitForExistence(timeout: 5))
        XCTAssertFalse(esCompacta, "### a pantalla completa no puede haber barra de pestañas")
        parada("MT-1-ancha")

        let estrecha = ancho(0.28)
        print("### estrecha: \(Int(estrecha)) pt, compacta=\(esCompacta)")
        XCTAssertLessThan(estrecha, 500, "### la ventana no se estrechó")
        XCTAssertTrue(esCompacta, "### en 375 pt la app tiene que dibujar su forma de teléfono")
        // **Lo que tiene que sobrevivir es DÓNDE estabas.** La ficha en sí no:
        // en compacto la pila del teléfono arranca en su hub, y volver a la
        // ficha es un toque. Lo que no puede pasar es aterrizar en Inicio,
        // que es lo que hacía antes: la sidebar mira `seccion`, las pestañas
        // miran `pestana`, y no se hablaban.
        let pestanaViva = app.tabBars.firstMatch.buttons.allElementsBoundByIndex
            .first { $0.isSelected }?.label
        print("### pestaña al estrechar: \(pestanaViva ?? "ninguna")")
        XCTAssertEqual(pestanaViva, "Treasury",
                       "### al caer a compacto se perdió la sección: aterrizó en \(pestanaViva ?? "?")")
        parada("MT-2-estrecha")

        pantallaCompleta()
        let ancha = app.frame.width
        print("### de vuelta: \(Int(ancha)) pt, compacta=\(esCompacta)")
        XCTAssertGreaterThan(ancha, 1000, "### la ventana no volvió")
        XCTAssertFalse(esCompacta, "### al volver a ancha tiene que irse la barra de pestañas")
        // Y al ensanchar se vuelve a Ingresos, no a otra sección.
        XCTAssertTrue(app.buttons["Income"].firstMatch.isSelected,
                      "### al ensanchar no se volvió a la sección donde estaba")
        parada("MT-3-ancha-otra-vez")
    }

    /// **Una hoja abierta no sobrevive al cambio de clase, y está medido.**
    ///
    /// Las dos formas de la app son dos árboles distintos —`NavigationSplitView`
    /// en regular, `TabView` en compacto—, así que al cruzar la frontera se
    /// destruye el `@State` de la pantalla que presenta la hoja, y con él la
    /// hoja. Con la hoja de "Nuevo" eso se lleva por delante lo que hubiera
    /// escrito: medido, el importe y el concepto desaparecen.
    ///
    /// Queda marcado con `XCTExpectFailure` y no arreglado: sacar el borrador
    /// de las 44 hojas a un modelo compartido es un rediseño, no un arreglo de
    /// pantalla. Lo que sí se arregló —y esto lo comprueba— es que no se pierda
    /// además la SECCIÓN.
    ///
    /// **Se prueba con la hoja de filtros, que no trae teclado.** Con el
    /// teclado fuera, el asa de la ventana queda debajo y el arrastre no agarra
    /// —medido: tres intentos seguidos sin mover un píxel—, la tecla de ocultar
    /// teclado se dibuja fuera de pantalla con el iPad apaisado, y el botón
    /// "Zoom" tampoco responde con una hoja presentada.
    func testUnaHojaAbiertaNoSobreviveAlCambioDeClase() {
        seccion("Income")
        app.buttons["Filters"].firstMatch.tap(); sleep(2)
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 5), "### no se abrió la hoja de filtros")
        app.staticTexts["Tithe"].firstMatch
            .coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap(); sleep(1)
        parada("MT-4-filtros-ancha")

        let estrecha = ancho(0.28)
        print("### estrecha: \(Int(estrecha)) pt, compacta=\(esCompacta)")
        XCTAssertLessThan(estrecha, 500, "### la ventana no se estrechó: la prueba no medía nada")

        // Lo que SÍ tiene que sobrevivir: la sección.
        let pestanaViva = app.tabBars.firstMatch.buttons.allElementsBoundByIndex
            .first { $0.isSelected }?.label
        print("### pestaña: \(pestanaViva ?? "ninguna") · hoja=\(app.buttons["Done"].exists)")
        XCTAssertEqual(pestanaViva, "Treasury", "### también se perdió la sección")

        XCTExpectFailure("Una hoja abierta no sobrevive al cambio de clase: son dos árboles distintos") {
            XCTAssertTrue(app.buttons["Done"].exists, "### la hoja se cerró al cambiar de clase")
        }
        parada("MT-5-filtros-estrecha")
    }

    /// Y la forma de teléfono dentro del iPad es la del teléfono: cinco
    /// pestañas, sin sidebar.
    func testLaFormaEstrechaEsLaDelTelefono() {
        let estrecha = ancho(0.28)
        print("### estrecha: \(Int(estrecha)) pt")
        XCTAssertTrue(esCompacta)
        XCTAssertFalse(app.buttons["Hide Sidebar"].exists, "### en compacto no hay sidebar")
        let pestanas = app.tabBars.firstMatch.buttons.allElementsBoundByIndex.map(\.label)
        print("### pestañas: \(pestanas)")
        XCTAssertEqual(pestanas, ["Home", "Treasury", "To review", "Secretary", "Settings"])
        parada("MT-7-pestanas")
    }
}
