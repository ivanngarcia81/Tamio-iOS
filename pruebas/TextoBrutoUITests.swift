import XCTest

/// Texto que nadie escribe a propósito pero que llega: un nombre de iglesia
/// larguísimo en el membrete, emoji, comillas y comas dentro de un nombre.
///
/// **AVISO: esta prueba NO sirve todavía y no mide nada.** Se deja escrita para
/// que la siguiente sesión no la vuelva a empezar de cero, con los dos fallos ya
/// localizados:
///
/// 1. `app.keys["delete"]` no vacía el campo del nombre de la iglesia —el
///    volcado del 9-sep dejó el campo intacto—, así que los 500 caracteres se
///    concatenan con lo que ya había o no llegan a escribirse.
/// 2. Tras "Save" la navegación no sale de Ajustes: el volcado final sigue
///    enseñando la pantalla de Iglesia, así que nunca se llega al membrete, que
///    es lo único que se quería mirar.
///
/// Lo que sí quedó medido de aquí: un nombre de aportante con emoji, comillas y
/// coma (`Márquez "Peña", Lucía 🎉👨‍👩‍👧‍👦`) **entra tal cual en el campo** —el
/// volcado devuelve la cadena entera, con el emoji compuesto sin partir—. Lo que
/// no se comprobó es qué hace con ella el PDF de la constancia.
final class TextoBruto: XCTestCase {

    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments += ["-prefs.idioma", "ingles", "-AppleLanguages", "(en)"]
        app.launch(); sleep(2)
    }

    func parada(_ n: String) { print("MARCA:\(n)"); fflush(stdout); Thread.sleep(forTimeInterval: 3.2) }

    /// Nombre de iglesia de 500 caracteres: va al membrete de cartas, actas y
    /// reportes.
    func testNombreDeIglesiaLarguisimo() {
        app.tabBars.buttons["Settings"].tap(); sleep(2)
        let p = NSPredicate(format: "label BEGINSWITH 'Church'")
        let fila = app.buttons.matching(p).firstMatch
        guard fila.waitForExistence(timeout: 6) else { return XCTFail("no hay fila Church") }
        fila.tap(); sleep(3)

        let campos = app.textFields.allElementsBoundByIndex
        print("CAMPOS:" + campos.map { $0.placeholderValue ?? "?" }.joined(separator: "|"))
        guard let nombre = campos.first else { return XCTFail("no hay campos") }
        nombre.tap()
        // Vaciar
        for _ in 0..<40 { app.keys["delete"].tap() }
        let largo = String(repeating: "Iglesia Cristiana Evangélica Nueva Vida de la Colonia ", count: 9)
        nombre.typeText(String(largo.prefix(500)))
        sleep(1)
        parada("iglesia-nombre-largo")
        if app.buttons["Save"].exists { app.buttons["Save"].tap(); sleep(3) }

        // El membrete: un acta en PDF.
        app.tabBars.buttons["Secretary"].tap(); sleep(2)
        let actas = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Minutes'")).firstMatch
        if actas.exists { actas.tap(); sleep(3) }
        parada("actas-con-nombre-largo")
        print("ACTAS:" + app.staticTexts.allElementsBoundByIndex.map(\.label).prefix(20).joined(separator: "|"))
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
