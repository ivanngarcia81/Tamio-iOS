import XCTest

/// **La hoja de firma, con el dedo.**
///
/// `PKCanvasView` no es observable, así que lo único que repinta esta hoja es
/// el contador `trazos`. Cuando el cuerpo no lo leía, firmar no encendía
/// "Guardar" y la firma no se podía guardar. Se prueba en el aparato del
/// simulador porque es lo único que demuestra el repintado: compilar no.
final class FirmaIPad: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments += ["-prefs.idioma", "ingles", "-AppleLanguages", "(en)"]
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

        // **"Sign" es el extremo derecho de la fila, no su centro**: en el
        // centro está el rótulo, y ahí el toque no abre nada.
        let fila = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Treasurer signature'")).firstMatch
        XCTAssertTrue(fila.waitForExistence(timeout: 5))
        fila.coordinate(withNormalizedOffset: .init(dx: 0.92, dy: 0.5)).tap(); sleep(2)

        let guardar = app.buttons["Save"], borrar = app.buttons["Clear"]
        XCTAssertTrue(guardar.waitForExistence(timeout: 5), "### no se abrió la hoja de firma")
        XCTAssertFalse(guardar.isEnabled, "### sin dibujar nada, Guardar tiene que estar apagado")

        let a = app.coordinate(withNormalizedOffset: .init(dx: 0.40, dy: 0.42))
        let b = app.coordinate(withNormalizedOffset: .init(dx: 0.58, dy: 0.50))
        a.press(forDuration: 0.2, thenDragTo: b, withVelocity: .slow, thenHoldForDuration: 0.2)
        sleep(2)
        parada("F-tras-trazo")
        XCTAssertTrue(guardar.isEnabled, "### tras firmar, Guardar sigue apagado")
        XCTAssertTrue(borrar.isEnabled, "### tras firmar, Borrar sigue apagado")

        // Borrar deja la hoja como estaba, y el botón se vuelve a apagar.
        borrar.tap(); sleep(2)
        XCTAssertFalse(guardar.isEnabled, "### tras borrar, Guardar tiene que apagarse")

        a.press(forDuration: 0.2, thenDragTo: b, withVelocity: .slow, thenHoldForDuration: 0.2)
        sleep(2)
        guardar.tap(); sleep(2)
        XCTAssertFalse(app.buttons["Cancel"].exists, "### Guardar no cerró la hoja")
        parada("F-guardada")
    }
}

/// La misma hoja en el teléfono: `HojaFirma` es una sola y la abren las dos
/// plataformas (`ConfiguracionView` y `IPhoneAjustesView`).
final class FirmaIPhone: XCTestCase {
    func testElTrazoEnciendeGuardar() {
        let app = XCUIApplication()
        app.launchArguments += ["-prefs.idioma", "ingles", "-AppleLanguages", "(en)"]
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
        XCTAssertFalse(guardar.isEnabled)
        let a = app.coordinate(withNormalizedOffset: .init(dx: 0.35, dy: 0.35))
        let b = app.coordinate(withNormalizedOffset: .init(dx: 0.65, dy: 0.42))
        a.press(forDuration: 0.2, thenDragTo: b, withVelocity: .slow, thenHoldForDuration: 0.2)
        sleep(2)
        print("MARCA:FT-tras-trazo"); fflush(stdout); Thread.sleep(forTimeInterval: 3)
        XCTAssertTrue(guardar.isEnabled, "### en el teléfono, tras firmar, Guardar sigue apagado")
    }
}
