import XCTest

/// **La hoja de firma, con el dedo.**
///
/// `PKCanvasView` no es observable, así que lo único que repinta esta hoja es
/// el contador `trazos`. Cuando el cuerpo no lo leía, firmar no encendía
/// "Guardar" y la firma no se podía guardar. Se prueba en el aparato del
/// simulador porque es lo único que demuestra el repintado: compilar no.
final class FirmaIPad: XCTestCase {
    var app: XCUIApplication!

    /// **Solo iPad**: gira a apaisado y busca la firma en la Configuración de
    /// la barra lateral. En el iPhone físico (23-sep) daba roja buscando
    /// «Treasurer signature»; el teléfono lo cubre `FirmaIPhone`.
    override func setUpWithError() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "solo iPad")
    }

    override func setUp() {
        continueAfterFailure = true
        app = XCUIApplication()
        // `-prefs.bienvenidaVista` salta el recorrido de bienvenida: es un
        // valor volátil de `UserDefaults`, así que la prueba no depende de
        // que el contenedor del simulador ya lo tenga puesto. Sin él, un
        // contenedor recién estrenado abre la app en la bienvenida y no hay
        // ni sidebar ni pestañas.
        // `-modoRevision YES`: la hoja de firma no lee nada de la iglesia, y
        // así la prueba corre también en un simulador sin sesión (sin él se
        // queda en «Sign in» y no mide nada).
        app.launchArguments += ["-bloqueo.biometrico", "NO", "-modoRevision", "YES",
                                "-prefs.idioma", "ingles", "-AppleLanguages", "(en)",
                                "-prefs.bienvenidaVista", "YES"]
        app.launch(); sleep(2)
        XCUIDevice.shared.orientation = .landscapeLeft; sleep(3)
    }
    override func tearDown() { XCUIDevice.shared.orientation = .portrait; sleep(1) }

    func parada(_ n: String) { print("MARCA:\(n)"); fflush(stdout); Thread.sleep(forTimeInterval: 3.0) }

    func testElTrazoEnciendeGuardar() {
        let ajustes = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Settings'")).firstMatch
        if !(ajustes.exists && ajustes.isHittable) {
            app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'sidebar'")).firstMatch.tap(); sleep(1)
        }
        ajustes.tap(); sleep(2)
        app.buttons["Treasurer & pastor"].firstMatch.tap(); sleep(2)

        // **La fila entera tiene que abrir la hoja**, que es lo que dibuja: una
        // fila de lado a lado con «Sign» al fondo. El 23-sep (iPad físico y
        // simulador) NO la abría: el `Button` es `.plain` y su `HStack` no
        // lleva `contentShape`, así que solo responden los glifos de «Treasurer
        // signature» y de «Sign»; el hueco del `Spacer` es transparente al
        // dedo. Esta prueba tocaba el 92 % del ancho, que caía en ese hueco
        // (el «Sign» empieza hacia el 94 %). Fallo de la app, no del
        // instrumento: se deja rojo aquí y se sigue por «Sign» para medir el
        // resto.
        let fila = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Treasurer signature'")).firstMatch
        XCTAssertTrue(fila.waitForExistence(timeout: 5))
        fila.coordinate(withNormalizedOffset: .init(dx: 0.6, dy: 0.5)).tap(); sleep(2)
        if !app.buttons["Save"].waitForExistence(timeout: 3) {
            XCTFail("### tocar la fila de la firma por el medio no abre la hoja: solo responden sus letras")
            fila.staticTexts["Sign"].firstMatch.tap(); sleep(2)
        }

        let guardar = app.buttons["Save"], borrar = app.buttons["Clear"]
        XCTAssertTrue(guardar.waitForExistence(timeout: 5), "### no se abrió la hoja de firma")

        // **Desde `4b637b6` (17-sep) «Guardar» está SIEMPRE encendido** y, con
        // el lienzo en blanco, dice qué falta en vez de apagarse. Esta prueba
        // seguía exigiéndolo apagado. Lo que demuestra el repintado ahora es
        // «Borrar»: se apaga con el lienzo vacío y se enciende con el trazo
        // (`HojaFirma.swift`, `vacio`), y el aviso de lo que falta.
        let aviso = app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS[c] 'drawing the signature'")).firstMatch
        XCTAssertFalse(borrar.isEnabled, "### sin dibujar nada, Borrar tiene que estar apagado")
        guardar.tap(); sleep(2)
        XCTAssertTrue(aviso.waitForExistence(timeout: 5),
                      "### con el lienzo en blanco, Guardar no dice que falta la firma")
        XCTAssertTrue(guardar.exists, "### Guardar cerró la hoja con el lienzo en blanco")

        let a = app.coordinate(withNormalizedOffset: .init(dx: 0.40, dy: 0.42))
        let b = app.coordinate(withNormalizedOffset: .init(dx: 0.58, dy: 0.50))
        a.press(forDuration: 0.2, thenDragTo: b, withVelocity: .slow, thenHoldForDuration: 0.2)
        sleep(2)
        parada("F-tras-trazo")
        XCTAssertTrue(borrar.isEnabled, "### tras firmar, Borrar sigue apagado: el cuerpo no se repintó")
        XCTAssertFalse(aviso.exists, "### tras firmar, sigue diciendo que falta la firma")

        // Borrar deja la hoja como estaba, y el botón se vuelve a apagar.
        borrar.tap(); sleep(2)
        XCTAssertFalse(borrar.isEnabled, "### tras borrar, Borrar tiene que apagarse")

        // **Se cierra con «Cancel», no se guarda**: una firma guardada se queda
        // en el aparato (`FirmasLocales`), cambia la fila a imagen + papelera,
        // y en la corrida siguiente el toque del extremo derecho cae en la
        // papelera y la BORRA en vez de abrir la hoja.
        app.buttons["Cancel"].tap(); sleep(2)
        XCTAssertFalse(guardar.exists, "### Cancel no cerró la hoja")
    }
}

/// La misma hoja en el teléfono: `HojaFirma` es una sola y la abren las dos
/// plataformas (`ConfiguracionView` y `IPhoneAjustesView`).
final class FirmaIPhone: XCTestCase {
    /// **Solo iPhone**: entra por la barra de pestañas, que el iPad no tiene.
    /// En el iPad físico (23-sep) daba roja con «No matches found for
    /// Descendants matching type TabBar»; el iPad lo cubre `FirmaIPad`.
    override func setUpWithError() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "solo iPhone")
    }

    func testElTrazoEnciendeGuardar() {
        let app = XCUIApplication()
        // `-prefs.bienvenidaVista` salta el recorrido de bienvenida: es un
        // valor volátil de `UserDefaults`, así que la prueba no depende de
        // que el contenedor del simulador ya lo tenga puesto. Sin él, un
        // contenedor recién estrenado abre la app en la bienvenida y no hay
        // ni sidebar ni pestañas.
        app.launchArguments += ["-bloqueo.biometrico", "NO",
                                "-prefs.idioma", "ingles", "-AppleLanguages", "(en)",
                                "-prefs.bienvenidaVista", "YES"]
        app.launch(); sleep(3)
        app.tabBars.buttons["Settings"].tap(); sleep(2)
        let fila = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Treasurer & pastor'")).firstMatch
        for _ in 0..<4 where !fila.isHittable { app.swipeUp(velocity: .slow); sleep(1) }
        fila.tap(); sleep(2)
        // En el teléfono la fila de la firma no es un `Button`: es una celda
        // con `onTapGesture`, así que se toca por su rótulo.
        let firma = app.staticTexts["Signature"].firstMatch
        for _ in 0..<5 where !firma.isHittable { app.swipeUp(velocity: .slow); sleep(1) }
        firma.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap(); sleep(2)
        let guardar = app.buttons["Save"]
        XCTAssertTrue(guardar.waitForExistence(timeout: 5), "### no se abrió la hoja de firma")
        // Desde `4b637b6` (17-sep) Guardar está SIEMPRE encendido y, con el
        // lienzo en blanco, dice qué falta en vez de apagarse. Se comprueba
        // eso, y que el trazo lo quita: el aviso solo se pinta mientras
        // `faltan` no esté vacío (`HojaFirma.swift`, `avisoDeFaltantes`).
        // No se guarda nada: la prueba no deja una firma en el aparato.
        let aviso = app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS[c] 'drawing the signature'")).firstMatch
        guardar.tap(); sleep(2)
        XCTAssertTrue(aviso.waitForExistence(timeout: 5),
                      "### con el lienzo en blanco, Guardar no dice que falta la firma")
        XCTAssertTrue(guardar.exists, "### Guardar cerró la hoja con el lienzo en blanco")
        let a = app.coordinate(withNormalizedOffset: .init(dx: 0.35, dy: 0.35))
        let b = app.coordinate(withNormalizedOffset: .init(dx: 0.65, dy: 0.42))
        a.press(forDuration: 0.2, thenDragTo: b, withVelocity: .slow, thenHoldForDuration: 0.2)
        sleep(2)
        print("MARCA:FT-tras-trazo"); fflush(stdout); Thread.sleep(forTimeInterval: 3)
        XCTAssertFalse(aviso.exists, "### en el teléfono, tras firmar, sigue diciendo que falta la firma")
    }
}
