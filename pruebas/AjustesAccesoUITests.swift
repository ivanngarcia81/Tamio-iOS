import XCTest

/// Ajustes → Acceso y áreas: la parada para medir el contraste del botón
/// apagado "Send invitation".
///
/// **"Sync now" ya no vive aquí**: `7aea1c0` (10-sep) lo mudó a la Zona de
/// riesgo (`ConfiguracionView.swift`, `SeccionZona.filaSincronizar`). Esta
/// prueba seguía buscándolo en Acceso y áreas y daba roja en el iPad físico
/// (23-sep). Ahora comprueba lo contrario: que no se quedó una copia aquí.
final class AjustesAcceso: XCTestCase {
    /// **Solo iPad.** Pide barra lateral o apaisado, y el iPhone no tiene
    /// ninguna de las dos (`project.yml`: solo vertical; `RootView`: la barra
    /// lateral solo con `.regular`). Corrida en el teléfono daba rojas que no
    /// decían nada de la app: ver `docs/ROJAS-SEPTIEMBRE.md`.
    override func setUpWithError() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "solo iPad")
    }

    func testParadaEnAccesoYAreas() {
        let app = XCUIApplication()
        // `-prefs.bienvenidaVista` salta el recorrido de bienvenida: es un
        // valor volátil de `UserDefaults`, así que la prueba no depende de
        // que el contenedor del simulador ya lo tenga puesto. Sin él, un
        // contenedor recién estrenado abre la app en la bienvenida y no hay
        // ni sidebar ni pestañas.
        // `-modoRevision YES`: sin sesión, que es lo que mide la parada (el
        // botón apagado), y así corre también en un simulador sin cuenta.
        app.launchArguments += ["-prefs.idioma", "ingles", "-AppleLanguages", "(en)",
                                "-prefs.bienvenidaVista", "YES", "-modoRevision", "YES"]
        // Candado apagado por argumento: un bloqueo guardado en el aparato
        // la dejaría tapada (ver LEEME.md, «El candado y las corridas»).
        app.launchArguments += ["-bloqueo.biometrico", "NO"]
        app.launch(); sleep(2)
        XCUIDevice.shared.orientation = .landscapeLeft; sleep(3)
        let ajustes = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Settings'")).firstMatch
        if !(ajustes.exists && ajustes.isHittable) {
            app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'sidebar'")).firstMatch.tap(); sleep(1)
        }
        ajustes.tap(); sleep(2)
        app.buttons["Access & areas"].firstMatch.tap(); sleep(3)
        // **Sin nada que hacer, ya no son botones: son texto.** Es lo que se
        // mide aquí, y de paso lo que hace que el rótulo se lea.
        let invitar = app.staticTexts["Send invitation"].firstMatch
        XCTAssertTrue(invitar.waitForExistence(timeout: 5), "### no está «Send invitation»")
        print("### invitar \(invitar.frame)")
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Send invitation'")).count, 0,
                       "### sin correo escrito no puede haber botón")
        // La sincronización se mudó a la Zona de riesgo: ni texto ni botón aquí.
        XCTAssertFalse(app.descendants(matching: .any)
                        .matching(NSPredicate(format: "label BEGINSWITH 'Sync now'")).firstMatch.exists,
                       "### «Sync now» sigue también en Acceso y áreas: quedó duplicado")
        print("MARCA:AC-acceso"); fflush(stdout); Thread.sleep(forTimeInterval: 3)

        // Y en cuanto hay correo escrito, vuelve a ser un botón de verdad.
        // El campo de correo no tiene marcador ni etiqueta —es un
        // `TextField("")` al lado de su rótulo—, así que se toca por la
        // derecha de la fila "Email".
        let rotulo = app.staticTexts["Email"].firstMatch
        if rotulo.waitForExistence(timeout: 3) {
            app.coordinate(withNormalizedOffset: .zero)
                .withOffset(CGVector(dx: rotulo.frame.midX + 300, dy: rotulo.frame.midY))
                .tap()
            app.typeText("prueba@correo.mx"); sleep(2)
            XCTAssertEqual(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Send invitation'")).count, 1,
                           "### con correo escrito tiene que volver a ser botón")
            print("MARCA:AC-con-correo"); fflush(stdout); Thread.sleep(forTimeInterval: 3)
        } else {
            print("### no encontré el campo de correo")
        }
        XCUIDevice.shared.orientation = .portrait
    }
}
