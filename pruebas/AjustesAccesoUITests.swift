import XCTest

/// Ajustes → Acceso y áreas: la parada para medir el contraste de los dos
/// botones apagados ("Send invitation" y "Sync now").
final class AjustesAcceso: XCTestCase {
    func testParadaEnAccesoYAreas() {
        let app = XCUIApplication()
        app.launchArguments += ["-prefs.idioma", "ingles", "-AppleLanguages", "(en)"]
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
        let sincronizar = app.staticTexts["Sync now"].firstMatch
        XCTAssertTrue(invitar.waitForExistence(timeout: 5))
        XCTAssertTrue(sincronizar.exists)
        print("### invitar \(invitar.frame) sincronizar \(sincronizar.frame)")
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Send invitation'")).count, 0,
                       "### sin correo escrito no puede haber botón")
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Sync now'")).count, 0,
                       "### sin sesión no puede haber botón")
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
