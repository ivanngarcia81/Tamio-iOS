import XCTest

/// Texto que nadie escribe a propósito pero que llega: un nombre de iglesia
/// larguísimo en el membrete, emoji, comillas y comas dentro de un nombre.
///
/// Corre con la maqueta (`-modoRevision YES`): el nombre de la iglesia que
/// escribe se queda en memoria. Sin ella dejaba renombrada la iglesia
/// sincronizada.
///
/// **Hasta el 24-sep no medía nada**, por dos fallos que llevaba apuntados: el
/// campo no se vaciaba y la prueba nunca salía de Ajustes. Los dos están
/// arreglados en `testNombreDeIglesiaLarguisimo`, que dice cómo.
///
/// Lo que sí quedó medido de aquí: un nombre de aportante con emoji, comillas y
/// coma (`Márquez "Peña", Lucía 🎉👨‍👩‍👧‍👦`) **entra tal cual en el campo** —el
/// volcado devuelve la cadena entera, con el emoji compuesto sin partir—. Lo que
/// no se comprobó es qué hace con ella el PDF de la constancia.
final class TextoBruto: XCTestCase {
    /// **Solo iPhone**: llega a Ajustes, Secretaría y Movimientos por pestañas.
    /// En el iPad físico (23-sep) daba roja con «No matches found for Descendants
    /// matching type TabBar» o su equivalente, que no dice nada de la app: es la
    /// omisión de las de iPad, al revés.
    override func setUpWithError() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "solo iPhone")
    }

    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments += ["-prefs.idioma", "ingles", "-AppleLanguages", "(en)"]
        // Candado apagado por argumento: un bloqueo guardado en el aparato
        // la dejaría tapada (ver LEEME.md, «El candado y las corridas»).
        app.launchArguments += ["-bloqueo.biometrico", "NO"]
        app.launchArguments += ["-modoRevision", "YES"]
        app.launch(); sleep(2)
    }

    func parada(_ n: String) { print("MARCA:\(n)"); fflush(stdout); Thread.sleep(forTimeInterval: 3.2) }

    /// Nombre de iglesia de 500 caracteres: va al membrete de cartas, actas y
    /// reportes. Lo que mide es que el campo lo acepte entero y que el acta
    /// se pueda generar con él; cómo queda el membrete se mira en la captura
    /// que se adjunta al resultado («acta-con-nombre-largo»).
    func testNombreDeIglesiaLarguisimo() {
        app.tabBars.buttons["Settings"].tap(); sleep(2)
        let p = NSPredicate(format: "label BEGINSWITH 'Church'")
        let fila = app.buttons.matching(p).firstMatch
        guard fila.waitForExistence(timeout: 6) else { return XCTFail("no hay fila Church") }
        fila.tap(); sleep(3)

        let nombre = app.textFields["e.g. New Life Church"]
        guard nombre.waitForExistence(timeout: 5) else {
            print("CAMPOS:" + app.textFields.allElementsBoundByIndex.map { $0.placeholderValue ?? "?" }.joined(separator: "|"))
            return XCTFail("no encuentro el campo del nombre")
        }
        // Vaciar con `typeText` y no con `app.keys["delete"].tap()`: en el
        // simulador (24-sep) la tecla no se dejaba pulsar —«Failed to scroll to
        // visible (by AX action) Key … 'delete'»—. El texto va alineado a la
        // derecha: se toca el extremo derecho para que el cursor quede detrás de
        // la última letra, y se borran tantas como tenga.
        let previo = nombre.value as? String ?? ""
        nombre.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.5)).tap(); sleep(1)
        nombre.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: previo.count + 5))
        let largo = String(String(repeating: "Iglesia Cristiana Evangélica Nueva Vida de la Colonia ", count: 10).prefix(500))
        nombre.typeText(largo)
        sleep(1)
        let escrito = nombre.value as? String ?? ""
        print("ESCRITO:\(escrito.count) caracteres")
        XCTAssertEqual(escrito, largo, "el campo no se quedó con los 500 caracteres")

        // Salir. No hay botón «Save»: se guarda al salir de la pantalla
        // (`IPhoneAjustesView`, `.onDisappear`). Y con el teclado arriba la
        // barra de pestañas está tapada, que es por lo que la versión anterior
        // no salía nunca de Ajustes.
        nombre.typeText("\n"); sleep(1)
        app.navigationBars.buttons.element(boundBy: 0).tap(); sleep(2)

        // El membrete: el PDF de un acta de la maqueta.
        app.tabBars.buttons["Secretary"].tap(); sleep(2)
        app.swipeUp(); sleep(1); app.swipeUp(); sleep(2)
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Minutes'")).firstMatch.tap(); sleep(3)
        app.cells.firstMatch.tap(); sleep(2)
        let pdf = app.buttons["PDF"].firstMatch
        guard pdf.waitForExistence(timeout: 8) else { return XCTFail("el acta no tiene botón de PDF") }
        pdf.tap(); sleep(5)
        XCTAssertTrue(app.staticTexts["PDF preview"].exists, "el acta no se generó con el nombre largo")
        let captura = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        captura.name = "acta-con-nombre-largo"
        captura.lifetime = .keepAlways
        add(captura)
        parada("acta-con-nombre-largo")
    }

    /// Emoji, comillas y comas en el nombre de un aportante nuevo.
    func testNombreConEmojiYComas() {
        app.tabBars.buttons["Treasury"].tap(); sleep(2)
        let p = NSPredicate(format: "label BEGINSWITH 'Contributors'")
        guard app.buttons.matching(p).firstMatch.waitForExistence(timeout: 6) else {
            return XCTFail("no hay fila Contributors")
        }
        app.buttons.matching(p).firstMatch.tap(); sleep(2)
        guard app.buttons["New"].exists else {
            print("BOTONES:" + app.buttons.allElementsBoundByIndex.map(\.label).joined(separator: "|"))
            return XCTFail("no hay botón New")
        }
        app.buttons["New"].tap(); sleep(3)
        let campos = app.textFields.allElementsBoundByIndex
        print("CAMPOS-APORTANTE:" + campos.map { $0.placeholderValue ?? "?" }.joined(separator: "|"))
        guard let nombre = campos.first else { return XCTFail("sin campos") }
        nombre.tap()
        nombre.typeText("Márquez \"Peña\", Lucía 🎉👨‍👩‍👧‍👦")
        sleep(1)
        parada("aportante-emoji")
        print("VALOR:\(nombre.value as? String ?? "?")")
        if app.navigationBars.buttons["Save"].isEnabled {
            app.navigationBars.buttons["Save"].tap(); sleep(3)
            parada("aportantes-tras-emoji")
            print("LISTA:" + app.staticTexts.allElementsBoundByIndex.map(\.label).prefix(20).joined(separator: "|"))
        }
    }
}
